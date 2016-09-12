**EN** | [RU](README_ru.md)

User Defined Functions (UDF)
============================


From [Official cite][firebird]:  
> A user defined function (UDF) in InterBase is merely a function written in any programming language that is compiled into a shared library. Under Windows platforms, shared libraries are commonly referred to as dynamic link libraries (DLL's).


At this moment all UDF-functions presented by:
* [atronah.dll][] - interface library file, which you have to put in `<firebrid_instance>/UDF` directory.
* [Padeg.dll][] - implementation library file, which you have to put in `<firebrid_instance>/bin` directory. This library downloaded from topic [Склонение фамилий, имен и отчеств по падежам Библиотека функций.](http://www.delphikingdom.ru/asp/viewitem.asp?UrlItem=/mastering/poligon/webpadeg.htm#SubHeader_1762079927060) by [link](http://www.delphikingdom.ru/zip/Padeg.zip) on 2016-09-12.

Current version of [atronah.dll][] compiled by **g++** compiler from [MinGW 5.3.0][mingw] with using [ib_util.dll][] library from [Firebird 2.5.5][firebird].
Compile command:
```shell
g++ -shared -o atronah.dll src/atronah.cpp -I ./include lib/ib_utils.dll
```


Available functions
-------------------

### inflect_name(name: string, case: int): string
Function to infect person's name for case.

**Input params:**
* `name` - string (maximum length is 1024 characters) with person's name to inflect
* `case` - number of target case. available values: 
    * 1 - Nominative
    * 2 - Genitive
    * 3 - Dative
    * 4 - Accusative
    * 5 - Ablative
    * 6 - Prepositional

**Return value:** cased persons's name or error code.

**Error codes:**
* -1 - incorrect case
* -2 - incorrect sex (deprecated)
* -3 - incorrect buffer size


**Query for declaration in Firebird:**
```sql
declare external function inflect_name
    cstring(1024), smallint
returns cstring(1024) FREE_IT
entry_point 'inflect_name' module_name 'atronah';
```

**Query for delete declaration:**
```sql
drop external function inflect_name;
```



[atronah.dll]: ./lib/atronah.dll
[Padeg.dll]: ./lib/Padeg.dll
[ib_util.dll]: ./lib/ib_util.dll
[mingw]: http://www.mingw.org/
[firebird]: http://www.firebirdsql.org/