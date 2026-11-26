/* =====================================================================
   05 · POWER BI İÇİN TEMİZLİK TABLOSU
   ---------------------------------------------------------------------
   Amaç   : Power BI'da (Veri Al → SQL Server → Gelişmiş seçenekler →
            SQL deyimi) "Veri ve Yöntem" sayfasındaki temizlik tablosunu
            beslemek. cleaning_log yalnızca silinen satırları tuttuğu için
            kalan satır ve yüzde burada hesaplanıyor.
   Not    : Başlangıç satır sayısı = temiz tablo + toplam silinen; böylece
            ara tablo (divvy_2025_prep) silinse de sorgu çalışır.
   ===================================================================== */

SELECT l.adim,
       l.kural,
       l.silinen,
       b.baslangic - SUM(l.silinen) OVER (ORDER BY l.adim ROWS UNBOUNDED PRECEDING) AS kalan,
       CAST(100.0 * l.silinen / b.baslangic AS decimal(5,2))                         AS silinen_yuzde
FROM dbo.cleaning_log l
CROSS JOIN (
    SELECT (SELECT COUNT(*) FROM dbo.divvy_2025_clean)
         + (SELECT SUM(silinen) FROM dbo.cleaning_log) AS baslangic
) b;
