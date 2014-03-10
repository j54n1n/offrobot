#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#inclucd <conio.h>

#define MAXSTR 1024

//大文字を小文字に
char ToLower(const char c)
{
   if ( c >= 'A' && c <= 'Z')
      return (c + 'a' - 'A' ); //小文字に変換
   else
      return c; //そのまま
}

//同じ長さの文字列を比較
int StrCmpare(const char *s1, const char *s2)
{
   int i = 0;
   while (ToLower(*s1) == ToLower(*s2)){
      if (*s1 == '\0')
         return 0;   //末尾まで等しい。
      s1++;
      s2++;
   }
   return (ToLower(*s1) - ToLower(*s2)); //等しくなかった文字の差を返す。
}

int main(int argc, char **argv)
{
   int i;
   char command[MAXSTR] = "";
   char exe_filename[MAXSTR];
   char filename[MAXSTR];
   char filename_short[MAXSTR];
   char *separater;
   
   /*-- コマンドプロンプトから"svgXphun2"を実行した場合 --*/
   if(StrCmpare(argv[0], "svgXphun2") == 0){ 
      for(i = 1; i < argc; i++){
         /*-- argv[i]にargv[i]の拡張子を格納。ファイルネームをショートネームにしてfilename_shortに格納。 --*/
         strcpy(filename, argv[i]);
         argv[i] += strlen(argv[i]) - 3;
         separater = strrchr(filename, '\\');
         separater++;
         strcpy(filename_short, separater);
         
         if(StrCmpare( "svg", argv[i] ) == 0){ //svgがD&Dされたとき、svg2phun2を実行。
            strcat(command, "svg2phun2.exe \"");
            strcat(command, filename);
            strcat(command, "\"");
            system(command);
            printf("\n[%2d/%2d]  Executed [svg2phun2.exe %s]. \n", i, argc-1, filename_short);
         }
         else if(StrCmpare( "phn", argv[i] ) == 0){ //phnがD&Dされたとき、phun2svg2を実行。
            strcat(command, "phun2svg2.exe \"");
            strcat(command, filename);
            strcat(command, "\"");
            system(command);
            printf("\n[%2d/%2d]  Executed [phun2svg2.exe %s]. \n", i, argc-1, filename_short);
         }
         else{ //その他がD&Dされたとき、エラーメッセージを出す。
            if ( i != argc - 1){
               printf("\n[%2d/%2d]  \"%s\" is neither [.phn] nor [.svg]. Press any key to continue... ", i, argc-1, filename_short);
               getch();
            } else {
               printf("\n[%2d/%2d]  \"%s\" is neither [.phn] nor [.svg]. Press any key to close... ", i, argc-1,filename_short);
               getch();
            }
         }
      }
      /*-- ファイルがD&Dされなかった時の処理 --*/
      if(argc == 1){
         printf("Usage:\n"
                "%s *.svg\n"
                " or \n"
                "%s *.phn\n"
                "\n"
                "Press any key to close...",
                "svg2phun.exe", "phun2svg.exe");
         getch();
      }
      return 0;
   }
   
   /*-- コマンドプロンプトから"svgXphun2.EXE"を実行した場合 --*/
   else if(StrCmpare(argv[0], "svgXphun2.exe") == 0){
      for(i = 1; i < argc; i++){
         /*-- argv[i]にargv[i]の拡張子を格納。ファイルネームをショートネームにしてfilename_shortに格納。 --*/
         strcpy(filename, argv[i]);
         argv[i] += strlen(argv[i]) - 3;
         separater = strrchr(filename, '\\');
         separater++;
         strcpy(filename_short, separater);
         
         if(StrCmpare( "svg", argv[i] ) == 0){ //svgがD&Dされたとき、svg2phun2を実行。
            strcat(command, "svg2phun2.exe \"");
            strcat(command, filename);
            strcat(command, "\"");
            system(command);
            printf("\n[%2d/%2d]  executed [svg2phun2.exe %s]. \n", i, argc-1, filename_short, filename_short);
         }
         else if(StrCmpare( "phn", argv[i] ) == 0){ //phnがD&Dされたとき、phun2svg2を実行。
            strcat(command, "phun2svg2.exe \"");
            strcat(command, filename);
            strcat(command, "\"");
            system(command);
            printf("\n[%2d/%2d]  executed [phun2svg2.exe %s]. \n", i, argc-1, filename_short, filename_short);
         }
         else{ //その他がD&Dされたとき、エラーメッセージを出す。
            if ( i != argc - 1){
               printf("\n[%2d/%2d]  \"%s\" is neither [.phn] nor [.svg]. Press any key to continue... ", i, argc-1, filename_short);
               getch();
            } else {
               printf("\n[%2d/%2d]  \"%s\" is neither [.phn] nor [.svg]. Press any key to close... ", i, argc-1, filename_short);
               getch();
            }
         }
      }
      /*-- ファイルがD&Dされなかった時の処理 --*/
      if(argc == 1){
         printf("Usage:\n"
                "%s *.svg\n"
                " or \n"
                "%s *.phn\n"
                "\n"
                "Press any key to close...",
                "svg2phun.exe", "phun2svg.exe");
         getch();
      }
      return 0;
   }
   
   /*-- argv[0]にカレントディレクトリへのフルパスを格納。実行ファイル名をショートネームにしてexe_filenameに格納。 --*/
   {
      separater = strrchr(argv[0], '\\'); 
      strcpy(exe_filename, ++separater);
      *separater = '\0';
   }
   
   /*-- ファイルがD&Dされた時の処理 --*/
   for(i = 1; i < argc; i++){
      /*-- argv[i]にargv[i]の拡張子を格納。ファイルネームをショートネームにしてfilename_shortに格納。 --*/
      strcpy(filename, argv[i]);
      argv[i] += strlen(argv[i]) - 3;
      separater = strrchr(filename, '\\');
      separater++;
      strcpy(filename_short, separater);
      
      if(StrCmpare( "svg", argv[i] ) == 0){ //svgがD&Dされたとき、svg2phun2
         strcpy(command, argv[0]);
         strcat(command, "svg2phun2.exe \"");
         strcat(command, filename);
         strcat(command, "\"");
         system(command);
         printf("\n[%2d/%2d]  Executed \"svg2phun2.exe %s\". \n", i, argc-1, filename_short);
      }
      else if(StrCmpare( "phn", argv[i] ) == 0){ //phnがD&Dされたとき、phun2svg2を実行。
         strcpy(command, argv[0]);
         strcat(command, "phun2svg2.exe \"");
         strcat(command, filename);
         strcat(command, "\"");
         system(command);
         printf("\n[%2d/%2d]  Executed \"phun2svg2.exe %s\". \n", i, argc-1, filename_short);
      }
      else{ //その他がD&Dされたとき、エラーメッセージを出す。
         if ( i != argc - 1){
            printf("\n[%2d/%2d]  \"%s\" is neither [.phn] nor [.svg]. Press any key to continue... ", i, argc-1, filename_short);
            getch();
         } else {
            printf("\n[%2d/%2d]  \"%s\" is neither [.phn] nor [.svg]. Press any key to close... ", i, argc-1, filename_short);
            getch();
         }
      }
   }
   //printf("\nFinished. Press any key to close...");
   //getch();
   
   /*-- ファイルがD&Dされなかった時の処理 --*/
   if(argc == 1){
      printf("Usage: Drag & Drop [.svg] or [.phn] files to [%s].\nPress any key to close...", exe_filename);
      getch();
   }
   return 0;
}
