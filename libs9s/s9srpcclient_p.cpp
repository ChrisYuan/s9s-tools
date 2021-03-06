/* 
 * Copyright (C) 2011-2016 severalnines.com
 */
#include "s9srpcclient_p.h"
 
#include <string.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <unistd.h>
#include <cerrno>

#include "S9sRegExp"
#include "S9sOptions"

//#define DEBUG
//#define WARNING
#include "s9sdebug.h"

S9sRpcClientPrivate::S9sRpcClientPrivate() :
    m_referenceCounter(1),
    m_requestId(0ull),
    m_socketFd(-1),
    m_port(0),
    m_useTls(false),
    m_buffer(0),
    m_bufferSize(0),
    m_dataSize(0),
    m_sslContext(0),
    m_ssl(0),
    m_callbackFunction(0),
    m_callbackUserData(0),
    m_authenticated(false)
{
}

S9sRpcClientPrivate::~S9sRpcClientPrivate()
{
    close();
    clearBuffer();
}

void 
S9sRpcClientPrivate::ref()
{
	++m_referenceCounter;
}

int 
S9sRpcClientPrivate::unRef()
{
	return --m_referenceCounter;
}

void 
S9sRpcClientPrivate::ensureHasBuffer(
        size_t   size)
{
    if (size <= m_bufferSize)
        return;

    if (m_buffer == NULL)
    {
        m_buffer     = (char *)malloc(size);
        m_bufferSize = size;

        return;
    }

    m_buffer     = (char *) realloc(m_buffer, size);
    m_bufferSize = size;
}

void
S9sRpcClientPrivate::clearBuffer()
{
    if (m_buffer != 0)
        free(m_buffer);

    m_buffer     = 0;
    m_bufferSize = 0;
    m_dataSize   = 0;
}

/**
 * \returns whether it connected successfully
 */
bool
S9sRpcClientPrivate::connect()
{
    struct hostent *hp;
    struct timeval timeout;
    struct sockaddr_in server;

    /*
     * disconnect first if there is a previous connection
     */
    if (m_socketFd > 0)
        close();

    if (m_hostName.empty())
    {
        m_errorString = "Controller host name is not set.";
        return false;
    }

    if (m_port <= 0)
    {
        m_errorString = "Controller port is not set.";
        return false;
    }

    PRINT_VERBOSE("Connecting to %s:%d...", STR(m_hostName), m_port);
    m_socketFd = socket(AF_INET, SOCK_STREAM, 0);
    if (m_socketFd == -1)
    {
        m_errorString.sprintf("Error creating socket: %m");
        return false;
    }

    /*
     * Setting up a read and write timeout values
     * (otherwise it hangs on interrupted connection)
     */
    timeout.tv_sec  = 240;
    timeout.tv_usec = 0;
    setsockopt(
            m_socketFd, SOL_SOCKET, SO_RCVTIMEO,
            (char*) &timeout, sizeof(timeout));

    setsockopt(
            m_socketFd, SOL_SOCKET, SO_SNDTIMEO,
            (char*) &timeout, sizeof(timeout));

    /*
     * lookup
     */
    hp = gethostbyname(STR(m_hostName));
    if (hp == NULL)
    {
        m_errorString.sprintf("Host '%s' not found.", STR(m_hostName));
        close();
        return false;
    }

    /*
     * Connecting to the server.
     * (TODO: IPv6)
     */
    memcpy((char *) &server.sin_addr, (char *) hp->h_addr, hp->h_length);
    server.sin_family = AF_INET;
    server.sin_port = htons(m_port);

    if (::connect(m_socketFd, (struct sockaddr *) &server, sizeof server) == -1)
    {
        m_errorString.sprintf(
                "Connect to %s:%d failed: %m.", 
                STR(m_hostName), m_port);
      
        close();
        return false;
    }

    PRINT_VERBOSE("Connected.");

    if (m_useTls)
    {
        PRINT_VERBOSE ("Initiate TLS...");

        static bool openSslInitialized;
        if (!openSslInitialized)
        {
            openSslInitialized = true;
            SSL_load_error_strings ();
            SSL_library_init ();
        }

        #if (OPENSSL_VERSION_NUMBER >= 0x10100000L)
        m_sslContext = SSL_CTX_new(TLS_client_method());
        #else
        m_sslContext = SSL_CTX_new(SSLv23_client_method());
        #endif

        if (!m_sslContext)
        {
            m_errorString = "Couldn't create SSL context.";
            close();
            return false;
        }

        SSL_CTX_set_verify(m_sslContext, SSL_VERIFY_NONE, NULL);
        SSL_CTX_set_options(m_sslContext,
                SSL_OP_ALL | SSL_OP_NO_SSLv2 | SSL_OP_NO_SSLv3);
        SSL_CTX_set_mode(m_sslContext, SSL_MODE_AUTO_RETRY);

        m_ssl = SSL_new(m_sslContext);

        if (!m_ssl)
        {
            m_errorString = "Couldn't create SSL.";
            close();
            return false;
        }

        SSL_set_fd(m_ssl, m_socketFd);
        SSL_set_connect_state(m_ssl);
        SSL_set_tlsext_host_name(m_ssl, STR(m_hostName));

        if (SSL_connect(m_ssl) <= 0 || SSL_do_handshake(m_ssl) <= 0)
        {
            m_errorString = "SSL handshake failed.";
            close();
            return false;
        }

        PRINT_VERBOSE("TLS handshake finished (version: %s, cipher: %s).",
            SSL_get_version(m_ssl), SSL_get_cipher(m_ssl));
    }

    return true;
}

void
S9sRpcClientPrivate::close()
{
    if (m_socketFd < 0)
        return;

    if (m_ssl)
    {
        SSL_shutdown(m_ssl);
        SSL_free(m_ssl);
        m_ssl = 0;
    }

    if (m_sslContext)
    {
        SSL_CTX_free(m_sslContext);
        m_sslContext = 0;
    }

    ::shutdown(m_socketFd, SHUT_RDWR);
    ::close(m_socketFd);
}

/**
 * write safely to a socket
 */
ssize_t
S9sRpcClientPrivate::write(
        const char *data, 
        size_t      length)
{
    ssize_t retval = -1;

    if (m_ssl)
        return SSL_write(m_ssl, data, length);

    do {
        retval = ::write(m_socketFd, data, length);
    } while (retval == -1 && errno == EINTR);

    return retval;
}

/**
 * read safely from a socket
 */
ssize_t
S9sRpcClientPrivate::read(
        char   *buffer, 
        size_t  bufSize)
{
    ssize_t retval = -1;
    int     loopCount = 0;

    if (m_ssl)
    {
        S9S_WARNING("calling SSL_read");
        return SSL_read(m_ssl, buffer, bufSize);
    }

    do {
        S9S_WARNING("calling read");
        retval = ::read(m_socketFd, buffer, bufSize);

        loopCount += 1;
        if (loopCount > 100)
            break;
    } while (retval == -1 && errno == EINTR);

    return retval;
}

/**
 * A bit higher level method, to parse out the cookies (HTTP session data) from
 * the read data (m_buffer)
 */
void
S9sRpcClientPrivate::parseHeaders()
{
    int lastIdx = 0;

    if (!m_buffer || m_dataSize < 12)
        return;

    S9sRegExp regexp("Set-Cookie: ([^=]*)=([^,;\r\n]*)");
    regexp.setIgnoreCase(true);

    S9sString buffer;

    buffer.assign(m_buffer, m_dataSize);

    while (lastIdx < (int) buffer.size() && regexp == buffer.substr(lastIdx))
    {
        m_cookies[regexp[1]] = regexp[2];
        lastIdx += regexp.firstIndex()+1;
    }

    lastIdx = 0;
    regexp  = S9sRegExp("Server: ([^\r\n]*)");

    if (regexp == buffer.substr(lastIdx))
        m_serverHeader = regexp[1];
}

/**
 * The HTTP cookie header lines must be sent on HTTP requests to the server
 */
S9sString
S9sRpcClientPrivate::cookieHeaders() const
{
    if (m_cookies.empty())
        return "";

    S9sString cookieHeader = "Cookie: ";

    S9sVariantMap::const_iterator it;
    for (it = m_cookies.begin(); it != m_cookies.end(); ++it)
    {
        if (cookieHeader != "Cookie: ")
            cookieHeader += "; ";

        S9sString keyVal;
        keyVal.sprintf("%s=%s", STR(it->first), STR(it->second.toString()));

        cookieHeader += keyVal;
    }

    cookieHeader += "\r\n";
    return cookieHeader;
}

/**
 * This simply returns the value of 'Server' header from the reply.
 */
S9sString
S9sRpcClientPrivate::serverVersionString() const
{
    return m_serverHeader;
}

/**
 * Replaces the buffer contents with the specified content, and reserves
 * additional space for further reading.  (incomplete JSon..)
 */
void
S9sRpcClientPrivate::setBuffer(
        S9sString &content, 
        int additionalSize)
{
    clearBuffer();   

    ensureHasBuffer(content.size() + additionalSize + 1);

    memcpy(m_buffer, STR(content), content.size());
    m_dataSize = content.size();
}

/**
 * \param title Just a string to be printed.
 *
 * A method for debugging.
 */
void
S9sRpcClientPrivate::printBuffer(
        const S9sString &title)
{
    ::printf("\n\n");
    ::printf("%s\n", STR(title));

    for (int n = 0; n < (int) m_dataSize; ++n)
    {
        int c = m_buffer[n];

        if (c == '\036')
        {
            ::printf("%s\\36%s", TERM_RED, TERM_NORMAL);
        } else if (c == '\n')
        {
            ::printf("\\n");
        } else if (c == '\r')
        {
            ::printf("\\r");
        } else if (c >= 'a' && c < 'z')
        {
            ::printf("%c", c);
        } else if (c >= 'A' && c < 'Z')
        {
            ::printf("%c", c);
        } else if (c >= '!' && c < '/')
        {
            ::printf("%c", c);
        } else if (c >= '0' && c < '9')
        {
            ::printf("%c", c);
        } else if (c == '{' || c == '}' || c == '[' || c == ']')
        {
            ::printf("%c", c);
        } else if (c == ' ')
        {
            ::printf("%c", c);
        } else {
            ::printf("\\%02d", c);
        }

        //printf(" ");
        if (n % 40 == 0 && n != 0)
            printf("\n");
    }

    printf("\n");
    fflush(stdout);
}

/**
 * \returns True if there is at least one complete JSon string is in the 
 * buffer.
 *
 * This method can be used when processing a JSon stream, otherwise it may
 * return false negatives. When streaming the end of the JSon string is marked
 * by either a '\036' character or an empty line.
 */
bool
S9sRpcClientPrivate::hasCompleteJSon() const
{
    if (m_buffer == NULL)
        return false;

    if (memmem(m_buffer, m_dataSize, "\n\n", 2) != NULL)
        return true;

    if (memchr(m_buffer, m_dataSize, '\036') != NULL)
        return true;

    return false;
}

/**
 * \returns One JSon string.
 *
 * This method can be used only when JSon streaming is processed. When streaming
 * the end of the JSon string is marked by either a '\036' character or an empty
 * line.
 */
S9sString 
S9sRpcClientPrivate::getCompleteJSon() const
{
    S9sString retval;
    char      previousChar = '\0';

    for (uint idx = 0; idx < m_dataSize; ++idx)
    {
        char c = m_buffer[idx];

        if (idx == 0 && c == '\036')
            continue;

        if (c == '\036')
            break;

        if (c == '\n' && previousChar == '\n')
            break;

        retval += c;
        previousChar = c;
    }

    return retval;
}

/**
 * \returns True if the JSon string was removed from the buffer.
 *
 * This method can be used only when JSon streaming is processed. When streaming
 * the end of the JSon string is marked by either a '\036' character or an empty
 * line.
 */
bool
S9sRpcClientPrivate::skipRecord()
{
    char *nextRecord;
    size_t remaining;
    size_t recordSize;
    
    nextRecord = (char *) memmem(m_buffer, m_dataSize, "\n\n", 2);
    if (nextRecord == NULL)
        return false;

    nextRecord += 2;
    if (*nextRecord == '\036')
        ++nextRecord;

    recordSize = nextRecord - m_buffer;
    remaining  = m_dataSize - recordSize;
    if (remaining == 0)
    {
        m_dataSize = 0;
        return true;
    }

    memmove(m_buffer, nextRecord, remaining);
    m_dataSize = remaining;
    return true;
}

