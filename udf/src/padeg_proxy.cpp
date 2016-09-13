#include <stdio.h>
#include <cstring>

#include <Windows.h>
#include <ib_util.h>

extern "C" char* inflect_name(char *name, int *c, int *sex){
    HINSTANCE hDLL;
    typedef int (__stdcall *LPFNGetFIOPadegFSAS)
      (unsigned char *, int, unsigned char *, int &);
    LPFNGetFIOPadegFSAS lpfnGetFIOPadegFSAS;
    typedef int (__stdcall *LPFNGetFIOPadegFS)
      (unsigned char *, int, int, unsigned char *, int &);
    LPFNGetFIOPadegFS lpfnGetFIOPadegFS;
    char * inflected_name;
    char cResult[1024];
    int len = 1024;
    int state = -999;

    // http://www.delphikingdom.ru/asp/viewitem.asp?UrlItem=/mastering/poligon/webpadeg.htm#SubHeader_1762079927060
    hDLL = LoadLibrary("Padeg.dll");
    inflected_name = (char*)ib_util_malloc(8);
    if (hDLL != NULL){
        if (*sex == 1 || *sex == 2) {
            lpfnGetFIOPadegFS = (LPFNGetFIOPadegFS)GetProcAddress(hDLL, "GetFIOPadegFS");
            if (lpfnGetFIOPadegFS != NULL) {
                state = lpfnGetFIOPadegFS((unsigned char *)name, *sex == 1 ? 1 : 0, *c, (unsigned char *)cResult, len);
            }
        } else{
            lpfnGetFIOPadegFSAS = (LPFNGetFIOPadegFSAS)GetProcAddress(hDLL, "GetFIOPadegFSAS");
            if (lpfnGetFIOPadegFSAS != NULL) {
                state = lpfnGetFIOPadegFSAS((unsigned char *)name, *c, (unsigned char *)cResult, len);
            }
        }
        /* Возможные результаты выполнения
                0 — успешное завершение;
                -1 — недопустимое значение падежа;
                -2 — недопустимое значение рода;
                -3 — размер буфера недостаточен для размещения результата преобразования ФИО.
        */
        if (state == 0) {
            inflected_name = (char*)ib_util_malloc(len + 1);
            strcpy(inflected_name, cResult);
        }else{
            sprintf(inflected_name, "%i (%i)", state, *c);
        }

        FreeLibrary(hDLL);
    }
    return inflected_name;
}
