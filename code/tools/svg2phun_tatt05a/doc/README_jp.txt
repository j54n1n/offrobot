t0m0tomoさんに許可を得て、ファイルを改変・公開させていただきました。
※t0m0tomoさんはsvg2phunの作者です。

svg2phun2  (C) tatt61880
               http://www.sakai.zaq.ne.jp/dugyj708/svg2phun_tatt/index.html
               http://jp.youtube.com/watch?v=LkQLm6B9w4s

svg2phun   (C) t0m0tomoさん
               http://www.nicovideo.jp/watch/sm2589929 (2008-)
               http://jp.youtube.com/watch?v=PPhOBfFEjHA
               http://www.geocities.jp/int_real_float/svg2phun/

=====================
■目的：

  SVG形式のデータ と Phun形式のデータを相互に変換します。
  SVG形式は Adobe Illustrator や Inkscape でサポートされているフォーマットです。
  この変換プログラムはレイヤーやグループ化もサポートしています。

■使い方(1)：

 (1) SVGファイルかphunファイルをsvgXphun2.exeにドラッグ＆ドロップしてください。

 phun2svg.exe自体は、Phun beta 4.0 ～ 4.22のファイルのみに対応しています。
 t0m0tomoさんのsvg2phun-06e.zipをダウンロードして、phun2svg.exeをsvgXphun2.exeや
 phun2svg2.exeと同じフォルダに入れると、Phun beta 3.5以前のphnファイルも同時に扱
 うことができるようになります。
 （svgXphun2.exeにファイルをドロップするだけです）
 
 (2) ほどなく元 ファイルがあるフォルダに、変換されたファイルが現れます。

  たとえば、file.svg を svgXphun.exe にドラッグ＆ドロップすると、
  file.phn が生成されます。

  一度に複数のファイルをドラッグ＆ドロップできます。SVGファイルとphun
  ファイルが混在していてもかまいません。

  オプション：
    config.txt で Phun オブジェクトのデフォルト値を設定をすることができます。
    設定をコメントアウトしたり削除すると、デフォルトのデフォルト値が採用されます。

■使い方(2)：

  コマンドプロンプトで、以下のコマンドを実行。 
  > svgXphun2 file.svg
  または
  > svgXphun2 file.phn

■内容物：
│
│  config.txt    ....... 設定ファイル
│  phun2svg2.exe ....... Phun を SVG に変換する実行ファイル
│  svg2phun2.exe ....... SVG を Phun に変換する実行ファイル
│  svgXphun2.exe ....... SVG <-> Phun 変換する実行ファイル
│  
├─doc
│      README.txt ...... 英語
│      README_jp.txt ... このファイル
│      
├─perl
│      config.txt ...... 設定ファイル
│      phun2svg2.pl .... phun2svg2.exe の元になった Perl スクリプト
│      svg2phun2.pl .... svg2phun2.exe の元になった Perl スクリプト
│      
├─svgXphun2_source
│      svgXphun2.c ..... svgXphun2.exe のソースファイル
│      
└─svg_data ............ SVG形式のファイル群（後述）
        addFixjoint.svg
        addHinge.svg
        addPen.svg
        addwaterdrop.svg

■どのようにSVGファイルをPhunファイルに変換するか。
   (1) 閉じたパスを変換します。
       開いたパスは変換されません。必ずパスを閉じてください。
   
   (2) 線と衝突属性
       SVGのオブジェクトのパスの線が衝突属性を設定します。
       線がない場合、どの衝突グループにも属しません。
       線が破線の場合、水との衝突が無効になります。
       衝突グループの詳細は、Phun内部で設定してください。

   (3) Hinge は塗りのない実線の円
   
   (4) Fixjoint（固定具） は蝶ネクタイ型の実践塗りなしのポリゴン
       svg_data フォルダの addFixjoint.svg を参考にしてください。
   
   (5) Spring は直線
       直線は Spring (バネ)に変換されます。線の太さがバネの太さに対応
       します。複数の直線が閉じている場合には、多角形に変換されます。

   (6) Plane は直線
       直線の両端がどのオブジェクトにもリンクされていない場合には、直
       線は Plane (平面)に変換されます。

   (7) Pen は塗りのない破線の円
       

   (8) レイヤーやグループ化されたオブジェクトは、「同一の物体」として
       変換されます。 
       
       同一レイヤー上のオブジェクトには、Phun ファイルにおいて同じ
       body 番号が付与されます。つまり、Phun において同一の物体であると
       みなされます。グループ化されたオブジェクトも同様に変換されます。

       複数のレイヤー上にグループ化されたオブジェクトが存在する場合には、
       レイヤーによるグルーピングが優先します。

       したがって、Fixate の機能はレイヤーやグループで代替されています。
       このため、FixateのDestroy keyを使用したphnファイルの変換が不完全です。

       なお、Illustrator 形式 (*.ai) でレイヤーを用いた場合でも、
       SVG 形式で保存すると、グループ化になるようです
       
   (9) 複合パスをサポートしていません。
       複合パスとは、「穴が空いた図形」です（たとえばドーナツ）。このよ
       うな図形を Phun はサポートしていません。今後に期待しましょう。
       現状では、複合パスは複数の独立したオブジェクトに変換されます。
       
   (10) Illustrator を用いて SVG 形式に保存する際の注意
       SVG 1.1 
       OFF: Illustrator の編集機能を保持 
       OFF: Adobe SVG Viewer 用に最適化
       OFF: Adobe Graphic Server データを含める
       OFF: スライスデータを含める
       OFF: XMP を含める
       ON:  <tspan>エレメントの出力を制御
       OFF: パス上テキストに<textPath>エレメントを使用
       
   (11) Inkscape を用いて SVG 形式に保存する際の注意
       Inkscape SVG 形式で保存してください。
       Plain SVG 形式で保存すると、円が多角形として変換されます。
       
   (12) 各種パラメータ
       各種パラメータは SVG の id オプションに保存されています。
       これらはPhunで調整することをお勧めします。どうしてもSVGエディタで
       調整したい場合は、

       Illustrator:
           レイヤーパネルを使ってください。

       Inkscape
            XMLエディタでを使ってください。

       データ形式は以下の形式です。
          <id=key:value;key:value; ....>

■svg_dataフォルダ内のデータについて
   例えば水を増やしたいなと思ったときは、waterdrop.svgのデータを
   編集中のSVGエディタの画面にコピペするだけ対応できます。

   ※Inkscapeではうまくいきます。
     Illustratorは持っていないので確認できていません。
           
■Perlスクリプトについて：
   同封してある Perl スクリプト svg2phun.pl でも実行できます。
   次のコマンドを実行してください。
   svg2phun.pl file.svg

   file.svg が存在するフォルダに file.phn が生成されます。実行には、
   SVG::Parser と Math::Bezier::Convert のモジュールが必要です。
   これらのモジュールはCPANから入手可能です。


Phunの発展を祈って。0:55 2008/11/08 by tatt618880