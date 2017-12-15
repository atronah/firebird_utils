**EN** | [RU][]

User Defined Functions (UDF)
============================

From [official cite][firebird]:
> A user defined function (UDF) in InterBase is merely a function written in any programming language that is compiled into a shared library.
Under Windows platforms, shared libraries are commonly referred to as dynamic link libraries (DLL's).

--------------------------------------------------------------------------------


Contents
--------
- [Libraries](#Libraries)
- [Available functions](#Available-functions)
    - [inflect_name](#inflect_namename-string-case-int-sex-int-string)

--------------------------------------------------------------------------------


Libraries
---------

Currently all UDF-functions are implemented by:

- [padeg_proxy.dll][] - interface library file, which you have to put in `<firebrid_instance>/UDF` directory.
This library provides wrapped version (suitable for use in Firebird) of functions from implementation library.
- [Padeg.dll][] - implementation library file, which you have to put in `<firebrid_instance>/bin` directory.
This library is a part of third-party project, which is described in article
[Склонение фамилий, имен и отчеств по падежам Библиотека функций.][padeg_source].
Current version of .dll file has been downloaded by [link](http://www.delphikingdom.ru/zip/Padeg.zip) on 2016-09-12.
- [Padeg.dll new](udf/inflect/PadegUC-20171215T100207Z-001.zip) - archive with new version of Padeg.dll
(supports win64 and contains Firebird UDF version of library).

Current version of [padeg_proxy.dll][] has been compiled by **g++** compiler from [MinGW 5.3.0][mingw]
using [ib_util.dll][] library from [Firebird 2.5.5][firebird].

Compile command:

```shell
g++ -shared -o padeg_proxy.dll src/padeg_proxy.cpp -I ./include lib/ib_utils.dll
```

--------------------------------------------------------------------------------


Available functions
-------------------

### inflect_name(name: string, case: int, sex: int): string

Function to inflect person's name for case.
Used procedures of original library [Padeg.dll][]:

- [GetFIOPadegFS][]  - if correct sex is given.
- [GetFIOPadegFSAS][] - if correct sex is not given.

**Input params:**

- `name` - string (maximum length is 1024 characters) with person's name to inflect (corresponds to `pFIO` params of original procedure).
- `case` - number of target case (corresponds to `nPadeg` params of original procedure).
- `sex` - sex of name. 1 - male, 2 - female, otherwise using auto detect sex by midname (patronym).
available values:
    - `1` - Nominative
    - `2` - Genitive
    - `3` - Dative
    - `4` - Accusative
    - `5` - Ablative
    - `6` - Prepositional

**Return value:** cased persons's name or error code.

**Error codes:**

- `-1` - incorrect case
- `-2` - incorrect sex (deprecated)
- `-3` - incorrect buffer size


**Query to declare function in Firebird:**

```sql
declare external function inflect_name
    cstring(1024), integer, integer
returns cstring(1024) FREE_IT
entry_point 'inflect_name' module_name 'padeg_proxy';
```

**Query to drop declaration:**
```sql
drop external function inflect_name;
```



[padeg_proxy.dll]: ./lib/padeg_proxy.dll
[Padeg.dll]: ./lib/Padeg.dll
[ib_util.dll]: ./lib/ib_util.dll
[mingw]: http://www.mingw.org/
[firebird]: http://www.firebirdsql.org/
[padeg_source]: http://www.delphikingdom.ru/asp/viewitem.asp?UrlItem=/mastering/poligon/webpadeg.htm#SubHeader_1762079927060
[GetFIOPadegFS]: http://www.delphikingdom.ru/asp/viewitem.asp?UrlItem=/mastering/poligon/webpadeg.htm#SubHeader_1714557337758
[GetFIOPadegFSAS]: http://www.delphikingdom.ru/asp/viewitem.asp?UrlItem=/mastering/poligon/webpadeg.htm#SubHeader_172811950154

[RU]: README_ru.md