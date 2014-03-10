#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#inclucd <conio.h>

#define MAXSTR 1024

//�啶������������
char ToLower(const char c)
{
   if ( c >= 'A' && c <= 'Z')
      return (c + 'a' - 'A' ); //�������ɕϊ�
   else
      return c; //���̂܂�
}

//���������̕�������r
int StrCmpare(const char *s1, const char *s2)
{
   int i = 0;
   while (ToLower(*s1) == ToLower(*s2)){
      if (*s1 == '\0')
         return 0;   //�����܂œ������B
      s1++;
      s2++;
   }
   return (ToLower(*s1) - ToLower(*s2)); //�������Ȃ����������̍���Ԃ��B
}

int main(int argc, char **argv)
{
   int i;
   char command[MAXSTR] = "";
   char exe_filename[MAXSTR];
   char filename[MAXSTR];
   char filename_short[MAXSTR];
   char *separater;
   
   /*-- �R�}���h�v�����v�g����"svgXphun2"�����s�����ꍇ --*/
   if(StrCmpare(argv[0], "svgXphun2") == 0){ 
      for(i = 1; i < argc; i++){
         /*-- argv[i]��argv[i]�̊g���q���i�[�B�t�@�C���l�[�����V���[�g�l�[���ɂ���filename_short�Ɋi�[�B --*/
         strcpy(filename, argv[i]);
         argv[i] += strlen(argv[i]) - 3;
         separater = strrchr(filename, '\\');
         separater++;
         strcpy(filename_short, separater);
         
         if(StrCmpare( "svg", argv[i] ) == 0){ //svg��D&D���ꂽ�Ƃ��Asvg2phun2�����s�B
            strcat(command, "svg2phun2.exe \"");
            strcat(command, filename);
            strcat(command, "\"");
            system(command);
            printf("\n[%2d/%2d]  Executed [svg2phun2.exe %s]. \n", i, argc-1, filename_short);
         }
         else if(StrCmpare( "phn", argv[i] ) == 0){ //phn��D&D���ꂽ�Ƃ��Aphun2svg2�����s�B
            strcat(command, "phun2svg2.exe \"");
            strcat(command, filename);
            strcat(command, "\"");
            system(command);
            printf("\n[%2d/%2d]  Executed [phun2svg2.exe %s]. \n", i, argc-1, filename_short);
         }
         else{ //���̑���D&D���ꂽ�Ƃ��A�G���[���b�Z�[�W���o���B
            if ( i != argc - 1){
               printf("\n[%2d/%2d]  \"%s\" is neither [.phn] nor [.svg]. Press any key to continue... ", i, argc-1, filename_short);
               getch();
            } else {
               printf("\n[%2d/%2d]  \"%s\" is neither [.phn] nor [.svg]. Press any key to close... ", i, argc-1,filename_short);
               getch();
            }
         }
      }
      /*-- �t�@�C����D&D����Ȃ��������̏��� --*/
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
   
   /*-- �R�}���h�v�����v�g����"svgXphun2.EXE"�����s�����ꍇ --*/
   else if(StrCmpare(argv[0], "svgXphun2.exe") == 0){
      for(i = 1; i < argc; i++){
         /*-- argv[i]��argv[i]�̊g���q���i�[�B�t�@�C���l�[�����V���[�g�l�[���ɂ���filename_short�Ɋi�[�B --*/
         strcpy(filename, argv[i]);
         argv[i] += strlen(argv[i]) - 3;
         separater = strrchr(filename, '\\');
         separater++;
         strcpy(filename_short, separater);
         
         if(StrCmpare( "svg", argv[i] ) == 0){ //svg��D&D���ꂽ�Ƃ��Asvg2phun2�����s�B
            strcat(command, "svg2phun2.exe \"");
            strcat(command, filename);
            strcat(command, "\"");
            system(command);
            printf("\n[%2d/%2d]  executed [svg2phun2.exe %s]. \n", i, argc-1, filename_short, filename_short);
         }
         else if(StrCmpare( "phn", argv[i] ) == 0){ //phn��D&D���ꂽ�Ƃ��Aphun2svg2�����s�B
            strcat(command, "phun2svg2.exe \"");
            strcat(command, filename);
            strcat(command, "\"");
            system(command);
            printf("\n[%2d/%2d]  executed [phun2svg2.exe %s]. \n", i, argc-1, filename_short, filename_short);
         }
         else{ //���̑���D&D���ꂽ�Ƃ��A�G���[���b�Z�[�W���o���B
            if ( i != argc - 1){
               printf("\n[%2d/%2d]  \"%s\" is neither [.phn] nor [.svg]. Press any key to continue... ", i, argc-1, filename_short);
               getch();
            } else {
               printf("\n[%2d/%2d]  \"%s\" is neither [.phn] nor [.svg]. Press any key to close... ", i, argc-1, filename_short);
               getch();
            }
         }
      }
      /*-- �t�@�C����D&D����Ȃ��������̏��� --*/
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
   
   /*-- argv[0]�ɃJ�����g�f�B���N�g���ւ̃t���p�X���i�[�B���s�t�@�C�������V���[�g�l�[���ɂ���exe_filename�Ɋi�[�B --*/
   {
      separater = strrchr(argv[0], '\\'); 
      strcpy(exe_filename, ++separater);
      *separater = '\0';
   }
   
   /*-- �t�@�C����D&D���ꂽ���̏��� --*/
   for(i = 1; i < argc; i++){
      /*-- argv[i]��argv[i]�̊g���q���i�[�B�t�@�C���l�[�����V���[�g�l�[���ɂ���filename_short�Ɋi�[�B --*/
      strcpy(filename, argv[i]);
      argv[i] += strlen(argv[i]) - 3;
      separater = strrchr(filename, '\\');
      separater++;
      strcpy(filename_short, separater);
      
      if(StrCmpare( "svg", argv[i] ) == 0){ //svg��D&D���ꂽ�Ƃ��Asvg2phun2
         strcpy(command, argv[0]);
         strcat(command, "svg2phun2.exe \"");
         strcat(command, filename);
         strcat(command, "\"");
         system(command);
         printf("\n[%2d/%2d]  Executed \"svg2phun2.exe %s\". \n", i, argc-1, filename_short);
      }
      else if(StrCmpare( "phn", argv[i] ) == 0){ //phn��D&D���ꂽ�Ƃ��Aphun2svg2�����s�B
         strcpy(command, argv[0]);
         strcat(command, "phun2svg2.exe \"");
         strcat(command, filename);
         strcat(command, "\"");
         system(command);
         printf("\n[%2d/%2d]  Executed \"phun2svg2.exe %s\". \n", i, argc-1, filename_short);
      }
      else{ //���̑���D&D���ꂽ�Ƃ��A�G���[���b�Z�[�W���o���B
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
   
   /*-- �t�@�C����D&D����Ȃ��������̏��� --*/
   if(argc == 1){
      printf("Usage: Drag & Drop [.svg] or [.phn] files to [%s].\nPress any key to close...", exe_filename);
      getch();
   }
   return 0;
}
