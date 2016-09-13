[EN][] | **RU**

Пользовательские функции (UDF)
==============================


Определение с [официального сайта][firebird]:
> A user defined function (UDF) in InterBase is merely a function written in any programming language that is compiled into a shared library. Under Windows platforms, shared libraries are commonly referred to as dynamic link libraries (DLL's).
Перевод:
> Пользовательские функции (user defined function, UDF) в InterBase - это простые функции, написаные на любом языке программирования и скомпилированные в разделяемую библиотеку. На Windows-платформах разделяемые библиотеки так же известны, как библиотеки динамической компановки (Dynamic Link Library, DLL).


Содержание
--------
* [Библиотеки](#Библиотеки)
* [Доступные пользовательские функции](#Доступные-пользовательские-функции)
    * [inflect_name](#inflect_namename-string-case-int-string)


Библиотеки
----------
На данный момент все UDF-функции реализованы с помощью следующих библиотек:
* [padeg_proxy.dll][] - интерфейсная библиотека, которую вы должны поместить в папку `<firebrid_instance>/UDF`.
Данная библиотека предоставляет удобные для вызова из Firebird обертки над функциями библиотеки реализации.
* [Padeg.dll][] - библиотека реализации функуионала, которую вы должны поместить в папку `<firebrid_instance>/bin`.
Данная библиотека является частьбю проекта, описанного в статье [Склонение фамилий, имен и отчеств по падежам Библиотека функций.][padeg_source]. Текущая версия библиотеки была скачена 2016-09-12 по [ссылке](http://www.delphikingdom.ru/zip/Padeg.zip).

Текущая версия библиотеки [padeg_proxy.dll][] скомпилированна с помощью **g++** компилятора из проекта [MinGW 5.3.0][mingw] с использованием библиотеки [ib_util.dll][] из [Firebird 2.5.5][firebird].
Команда для компиляции:
```shell
g++ -shared -o padeg_proxy.dll src/padeg_proxy.cpp -I ./include lib/ib_utils.dll
```


Доступные пользовательские функции
----------------------------------

### inflect_name(name: string, case: int): string
Функция для склонения Ф.И.О. человека в указаный падеж.
Использует [GetFIOPadegFSAS][] процедуру из [Padeg.dll][].

**Входные параметры:**
* `name` - Строка (максимальная длина которой состовляет 1024 символа) с Ф.И.О. человека, которые необходимо просклонять (cоответствует параметру `pFIO` ).
* `case` - Номер целевого падежа (cоответствует параметру `nPadeg` исходной процедуры).
Доступные значения:
    * 1 - Именительный
    * 2 - Родительный
    * 3 - Дательный
    * 4 - Винительный
    * 5 - Творительный
    * 6 - Предложный

**Вовзращаемое значение:** Склоненное в указанный падеж Ф.И.О. человека либо код ошибки, если склонение не удалось.

**Коды ошибок:**
* -1 - недопустимое значение падежа;
* -2 - недопустимое значение рода;
* -3 - размер буфера недостаточен для размещения результата преобразования ФИО.


**Запрос на объявление функции в Firebird:**
```sql
declare external function inflect_name
    cstring(1024), smallint
returns cstring(1024) FREE_IT
entry_point 'inflect_name' module_name 'padeg_proxy';
```

**Запрос на удаление объявленой ранее функции:**
```sql
drop external function inflect_name;
```



[padeg_proxy.dll]: ./lib/padeg_proxy.dll
[Padeg.dll]: ./lib/Padeg.dll
[ib_util.dll]: ./lib/ib_util.dll
[mingw]: http://www.mingw.org/
[firebird]: http://www.firebirdsql.org/
[padeg_source]: http://www.delphikingdom.ru/asp/viewitem.asp?UrlItem=/mastering/poligon/webpadeg.htm#SubHeader_1762079927060
[GetFIOPadegFSAS]: http://www.delphikingdom.ru/asp/viewitem.asp?UrlItem=/mastering/poligon/webpadeg.htm#SubHeader_172811950154
[EN]: README.md