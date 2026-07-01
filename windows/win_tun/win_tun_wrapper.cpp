#include "win_tun_wrapper.h"
#include <windows.h>
#include <iphlpapi.h>
#include <string>
#include <atomic>

// wintun.dll function pointer types
typedef struct _WINTUN_ADAPTER WINTUN_ADAPTER;
typedef struct _WINTUN_SESSION_HANDLE WINTUN_SESSION_HANDLE;

typedef WINTUN_ADAPTER* (WINAPI* WintunCreateAdapterFunc)(const wchar_t* Name, const wchar_t* TunnelType, BOOL* RebootRequired);
typedef void (WINAPI* WintunFreeAdapterFunc)(WINTUN_ADAPTER* Adapter);
typedef WINTUN_SESSION_HANDLE* (WINAPI* WintunStartSessionFunc)(WINTUN_ADAPTER* Adapter, DWORD Capacity);
typedef void (WINAPI* WintunEndSessionFunc)(WINTUN_SESSION_HANDLE* Session);
typedef DWORD (WINAPI* WintunReceivePacketFunc)(WINTUN_SESSION_HANDLE* Session, BYTE** Packet, DWORD* PacketSize);
typedef BOOL (WINAPI* WintunSendPacketFunc)(WINTUN_SESSION_HANDLE* Session, const BYTE* Packet, DWORD PacketSize);
typedef DWORD (WINAPI* WintunGetAdapterLuidFunc)(WINTUN_ADAPTER* Adapter, NET_LUID* Luid);

// Static function pointers
static HMODULE hWintun = nullptr;
static WintunCreateAdapterFunc pCreateAdapter = nullptr;
static WintunFreeAdapterFunc pFreeAdapter = nullptr;
static WintunStartSessionFunc pStartSession = nullptr;
static WintunEndSessionFunc pEndSession = nullptr;
static WintunReceivePacketFunc pReceivePacket = nullptr;
static WintunSendPacketFunc pSendPacket = nullptr;
static WintunGetAdapterLuidFunc pGetAdapterLuid = nullptr;

// Error handling
static std::atomic<bool> g_initialized{false};
static wchar_t g_lastError[512] = L"No error";

// Session state
struct SessionState {
    WINTUN_ADAPTER* adapter;
    WINTUN_SESSION_HANDLE* session;
    bool active;
};

static void SetError(const wchar_t* msg) {
    wcscpy_s(g_lastError, msg);
}

static bool EnsureWintunLoaded() {
    if (g_initialized) return true;

    // Try to load wintun.dll from the same directory as this DLL
    wchar_t dllPath[MAX_PATH];
    GetModuleFileNameW(NULL, dllPath, MAX_PATH);
    wchar_t* lastSlash = wcsrchr(dllPath, L'\\');
    if (lastSlash) {
        wcscpy_s(lastSlash + 1, MAX_PATH - (lastSlash - dllPath + 1), L"wintun.dll");
    }

    hWintun = LoadLibraryW(dllPath);
    if (!hWintun) {
        // Try System32
        hWintun = LoadLibraryW(L"wintun.dll");
    }
    if (!hWintun) {
        SetError(L"Failed to load wintun.dll");
        return false;
    }

    pCreateAdapter = (WintunCreateAdapterFunc)GetProcAddress(hWintun, "WintunCreateAdapter");
    pFreeAdapter = (WintunFreeAdapterFunc)GetProcAddress(hWintun, "WintunFreeAdapter");
    pStartSession = (WintunStartSessionFunc)GetProcAddress(hWintun, "WintunStartSession");
    pEndSession = (WintunEndSessionFunc)GetProcAddress(hWintun, "WintunEndSession");
    pReceivePacket = (WintunReceivePacketFunc)GetProcAddress(hWintun, "WintunReceivePacket");
    pSendPacket = (WintunSendPacketFunc)GetProcAddress(hWintun, "WintunSendPacket");
    pGetAdapterLuid = (WintunGetAdapterLuidFunc)GetProcAddress(hWintun, "WintunGetAdapterLuid");

    if (!pCreateAdapter || !pFreeAdapter || !pStartSession || !pEndSession ||
        !pReceivePacket || !pSendPacket) {
        SetError(L"Failed to load wintun.dll functions");
        FreeLibrary(hWintun);
        hWintun = nullptr;
        return false;
    }

    g_initialized = true;
    return true;
}

extern "C" {

WIN_TUN_API WintunSession WintunCreateAdapter(const wchar_t* adapterName, const wchar_t* tunnelType) {
    if (!EnsureWintunLoaded()) return nullptr;

    BOOL rebootRequired = FALSE;
    WINTUN_ADAPTER* adapter = pCreateAdapter(adapterName, tunnelType, &rebootRequired);
    if (!adapter) {
        SetError(L"WintunCreateAdapter failed");
        return nullptr;
    }

    SessionState* state = new SessionState();
    state->adapter = adapter;
    state->session = nullptr;
    state->active = false;
    return state;
}

WIN_TUN_API int WintunStartSession(WintunSession session, unsigned int capacity) {
    if (!session) return -1;
    SessionState* state = (SessionState*)session;

    state->session = pStartSession(state->adapter, capacity);
    if (!state->session) {
        SetError(L"WintunStartSession failed");
        return -1;
    }
    state->active = true;
    return 0;
}

WIN_TUN_API int WintunReceivePacket(WintunSession session, unsigned char* buffer, int bufferSize) {
    if (!session) return -1;
    SessionState* state = (SessionState*)session;
    if (!state->active || !state->session) return -1;

    BYTE* packet = nullptr;
    DWORD packetSize = 0;
    DWORD result = pReceivePacket(state->session, &packet, &packetSize);

    if (result == ERROR_SUCCESS) {
        // No packet available
        return 0;
    } else if (result == ERROR_NO_MORE_ITEMS) {
        // No packet available (alternative code)
        return 0;
    }

    if (!packet || packetSize == 0) return 0;
    if (packetSize > (DWORD)bufferSize) {
        SetError(L"Receive buffer too small");
        return -1;
    }

    memcpy(buffer, packet, packetSize);
    return (int)packetSize;
}

WIN_TUN_API int WintunSendPacket(WintunSession session, const unsigned char* buffer, int bufferSize) {
    if (!session) return -1;
    SessionState* state = (SessionState*)session;
    if (!state->active || !state->session) return -1;

    BOOL result = pSendPacket(state->session, buffer, bufferSize);
    return result ? 0 : -1;
}

WIN_TUN_API int WintunSetAdapterAddresses(WintunSession session, const wchar_t* ipv4Address, const wchar_t* ipv6Address) {
    // This requires MIB_IPFORWARD_TABLE2 etc. - simplified implementation
    // For production, use SetIpForwardEntry2 from netioapi.h
    if (!session) return -1;
    // TODO: Implement using Windows IP Helper API
    return 0;
}

WIN_TUN_API int WintunSetAdapterRoutes(WintunSession session, const wchar_t** routes, int routeCount) {
    // TODO: Implement using SetIpForwardEntry2 from netioapi.h
    return 0;
}

WIN_TUN_API int WintunSetAdapterDns(WintunSession session, const wchar_t** dnsServers, int dnsCount) {
    // TODO: Implement using SetDnsServerAddresses from netioapi.h
    return 0;
}

WIN_TUN_API int WintunGetAdapterLuid(WintunSession session, unsigned long long* luid) {
    if (!session || !luid) return -1;
    SessionState* state = (SessionState*)session;
    if (!state->adapter) return -1;

    NET_LUID nluid;
    if (pGetAdapterLuid) {
        DWORD result = pGetAdapterLuid(state->adapter, &nluid);
        if (result == NO_ERROR) {
            *luid = nluid.Value;
            return 0;
        }
    }
    return -1;
}

WIN_TUN_API void WintunStopSession(WintunSession session) {
    if (!session) return;
    SessionState* state = (SessionState*)session;
    if (state->session) {
        pEndSession(state->session);
        state->session = nullptr;
    }
    state->active = false;
}

WIN_TUN_API void WintunDeleteAdapter(WintunSession session) {
    if (!session) return;
    SessionState* state = (SessionState*)session;
    if (state->adapter) {
        pFreeAdapter(state->adapter);
        state->adapter = nullptr;
    }
    delete state;
}

WIN_TUN_API const wchar_t* WintunGetLastError() {
    return g_lastError;
}

} // extern "C"
