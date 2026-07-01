#pragma once

#ifdef WIN_TUN_EXPORTS
#define WIN_TUN_API __declspec(dllexport)
#else
#define WIN_TUN_API __declspec(dllimport)
#endif

#ifdef __cplusplus
extern "C" {
#endif

// Opaque handle to a Wintun adapter session
typedef void* WintunSession;

// Create a Wintun adapter
// adapterName: Name of the TUN adapter (e.g., "TeapodTUN")
// tunnelType: Name of the tunnel type (e.g., "TeapodStream")
// Returns: Handle to the adapter session, or NULL on failure
WIN_TUN_API WintunSession WintunCreateAdapter(const wchar_t* adapterName, const wchar_t* tunnelType);

// Start a session on the adapter
// session: Handle from WintunCreateAdapter
// capacity: Maximum packets in the queue (e.g., 256)
// Returns: 0 on success, non-zero on failure
WIN_TUN_API int WintunStartSession(WintunSession session, unsigned int capacity);

// Receive a packet from the TUN adapter
// session: Handle from WintunCreateAdapter
// buffer: Buffer to receive the packet data
// bufferSize: Size of the buffer
// Returns: Number of bytes received, or 0 if no packet available, -1 on error
WIN_TUN_API int WintunReceivePacket(WintunSession session, unsigned char* buffer, int bufferSize);

// Send a packet to the TUN adapter
// session: Handle from WintunCreateAdapter
// buffer: Packet data to send
// bufferSize: Size of the packet data
// Returns: 0 on success, -1 on error
WIN_TUN_API int WintunSendPacket(WintunSession session, const unsigned char* buffer, int bufferSize);

// Set adapter IP addresses
// session: Handle from WintunCreateAdapter
// ipv4Address: IPv4 address with CIDR (e.g., "10.0.0.1/24")
// ipv6Address: IPv6 address with CIDR (e.g., "fd00::1/128"), can be NULL
// Returns: 0 on success, -1 on error
WIN_TUN_API int WintunSetAdapterAddresses(WintunSession session, const wchar_t* ipv4Address, const wchar_t* ipv6Address);

// Set adapter routes
// session: Handle from WintunCreateAdapter
// routes: Array of CIDR routes (e.g., ["0.0.0.0/0", "::/0"])
// routeCount: Number of routes
// Returns: 0 on success, -1 on error
WIN_TUN_API int WintunSetAdapterRoutes(WintunSession session, const wchar_t** routes, int routeCount);

// Set adapter DNS servers
// session: Handle from WintunCreateAdapter
// dnsServers: Array of DNS server addresses (e.g., ["8.8.8.8", "8.8.4.4"])
// dnsCount: Number of DNS servers
// Returns: 0 on success, -1 on error
WIN_TUN_API int WintunSetAdapterDns(WintunSession session, const wchar_t** dnsServers, int dnsCount);

// Get adapter LUID (for route management)
// session: Handle from WintunCreateAdapter
// luid: Buffer to receive the LUID (8 bytes)
// Returns: 0 on success, -1 on error
WIN_TUN_API int WintunGetAdapterLuid(WintunSession session, unsigned long long* luid);

// Stop the session
// session: Handle from WintunCreateAdapter
WIN_TUN_API void WintunStopSession(WintunSession session);

// Delete the adapter
// session: Handle from WintunCreateAdapter
WIN_TUN_API void WintunDeleteAdapter(WintunSession session);

// Get last error message
// Returns: Human-readable error message
WIN_TUN_API const wchar_t* WintunGetLastError();

#ifdef __cplusplus
}
#endif
