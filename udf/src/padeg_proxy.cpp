#include <stdio.h>
#include <cstring>

#include <Windows.h>
#include <ib_util.h>

extern "C" char* inflect_name(char *name, int *c){
    HINSTANCE hDLL;
    typedef int (__stdcall *LPFNGetFIOPadegFSAS)
      (unsigned char *, int, unsigned char *, int &);
    LPFNGetFIOPadegFSAS lpfnGetFIOPadegFSAS;
    char * inflected_name;
    char cResult[1024];
    int len = 1024;
    int state = 0;

    // http://www.delphikingdom.ru/asp/viewitem.asp?UrlItem=/mastering/poligon/webpadeg.htm#SubHeader_1762079927060
    hDLL = LoadLibrary("Padeg.dll");
    inflected_name = (char*)ib_util_malloc(8);
    if (hDLL != NULL){
        lpfnGetFIOPadegFSAS = (LPFNGetFIOPadegFSAS)GetProcAddress(hDLL, "GetFIOPadegFSAS");
        if (lpfnGetFIOPadegFSAS != NULL) {
            /* Возможные результаты выполнения
            0 — успешное завершение;
            -1 — недопустимое значение падежа;
            -2 — недопустимое значение рода;
            -3 — размер буфера недостаточен для размещения результата преобразования ФИО.
            */
            state = lpfnGetFIOPadegFSAS((unsigned char *)name, *c, (unsigned char *)cResult, len);
            if (state == 0) {
                inflected_name = (char*)ib_util_malloc(len + 1);
                strcpy(inflected_name, cResult);
            }else{
                sprintf(inflected_name, "%i (%i)", state, c);
            }
        }
        FreeLibrary(hDLL);
    }
    return inflected_name;
}
