#ifndef WINDOWS_COMPAT_H
#define WINDOWS_COMPAT_H

#ifdef _WIN32
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <BaseTsd.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <windows.h>

#ifndef HAVE_STRUCT_TIMESPEC
#define HAVE_STRUCT_TIMESPEC
struct timespec
{
    long tv_sec;
    long tv_nsec;
};
#endif

#ifndef ssize_t
typedef SSIZE_T ssize_t;
#endif

static ssize_t portable_getline(char **lineptr, size_t *n, FILE *stream)
{
    if (!lineptr || !n || !stream)
    {
        errno = EINVAL;
        return -1;
    }

    if (*lineptr == NULL || *n == 0)
    {
        size_t initial_size = (*n > 0) ? *n : 128;
        char *new_ptr = (char *)malloc(initial_size);
        if (!new_ptr)
        {
            errno = ENOMEM;
            return -1;
        }
        *lineptr = new_ptr;
        *n = initial_size;
    }

    size_t position = 0;
    int ch = 0;

    while ((ch = fgetc(stream)) != EOF)
    {
        if (position + 1 >= *n)
        {
            size_t new_size = (*n) * 2;
            char *new_ptr = (char *)realloc(*lineptr, new_size);
            if (!new_ptr)
            {
                errno = ENOMEM;
                return -1;
            }
            *lineptr = new_ptr;
            *n = new_size;
        }

        (*lineptr)[position++] = (char)ch;

        if (ch == '\n')
        {
            break;
        }
    }

    if (position == 0 && ch == EOF)
    {
        return -1;
    }

    (*lineptr)[position] = '\0';
    return (ssize_t)position;
}

#define getline portable_getline

#ifndef strdup
#define strdup _strdup
#endif

#ifndef strcasecmp
#define strcasecmp _stricmp
#endif

#ifndef strncasecmp
#define strncasecmp _strnicmp
#endif

#ifndef popen
#define popen _popen
#endif

#ifndef pclose
#define pclose _pclose
#endif

static inline int nanosleep_compat(const struct timespec *req, struct timespec *rem)
{
    (void)rem;
    if (!req)
    {
        errno = EINVAL;
        return -1;
    }

    long long total_ns = (long long)req->tv_sec * 1000000000LL + req->tv_nsec;
    if (total_ns <= 0)
    {
        return 0;
    }

    DWORD milliseconds = (DWORD)((total_ns + 999999LL) / 1000000LL);
    Sleep(milliseconds);
    return 0;
}

#define nanosleep nanosleep_compat

#endif /* _WIN32 */

#endif /* WINDOWS_COMPAT_H */
