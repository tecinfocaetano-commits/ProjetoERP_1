package com.example.erp2026_pdv;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Paint;
import android.graphics.Rect;
import android.graphics.pdf.PdfDocument;

import java.io.File;
import java.io.FileOutputStream;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;

/**
 * Gera o cupom não fiscal da venda em PDF (PdfDocument nativo — sem
 * dependência externa). O arquivo vai para o cache do app e é
 * compartilhado via FileProvider.
 */
public final class CupomPdf {

    private CupomPdf() { }

    /**
     * Monta o PDF do cupom. {@code itens} são linhas prontas
     * ("descricao x qtd = total"). Devolve o File ou null em erro.
     */
    public static File gerar(Context contexto, String numeroVenda,
                             java.util.List<String> itens,
                             double subtotal, double desconto,
                             double total, double pago, double troco) {
        PdfDocument doc = new PdfDocument();
        Paint paint = new Paint();
        paint.setColor(0xFF000000);

        // uma página de 80mm de largura (~302pt a 72dpi) já comporta o cupom
        PdfDocument.PageInfo info = new PdfDocument.PageInfo.Builder(302, 600, 1)
                .create();
        PdfDocument.Page pagina = doc.startPage(info);
        Canvas canvas = pagina.getCanvas();

        float y = 40;
        Rect rect = new Rect();

        paint.setTextSize(16);
        paint.setFakeBoldText(true);
        canvas.drawText("ERP 2026 - PDV", 20, y, paint);
        y += 24;

        paint.setFakeBoldText(false);
        paint.setTextSize(11);
        String data = new SimpleDateFormat("dd/MM/yyyy HH:mm",
                Locale.getDefault()).format(new Date());
        canvas.drawText("Venda n. " + numeroVenda + "   " + data, 20, y, paint);
        y += 22;

        canvas.drawLine(20, y, 282, y, paint);
        y += 18;

        for (String linha : itens) {
            paint.getTextBounds(linha, 0, linha.length(), rect);
            if (rect.width() > 250) {
                linha = cortar(linha, paint, 250);
            }
            canvas.drawText(linha, 20, y, paint);
            y += 16;
            if (y > 540) {
                break; // cupom longo: segurança contra sair da página
            }
        }

        canvas.drawLine(20, y, 282, y, paint);
        y += 20;

        paint.setTextSize(12);
        canvas.drawText("Subtotal:  " + moeda(subtotal), 20, y, paint);
        y += 18;
        canvas.drawText("Desconto:  " + moeda(desconto), 20, y, paint);
        y += 18;
        paint.setFakeBoldText(true);
        paint.setTextSize(14);
        canvas.drawText("TOTAL:  " + moeda(total), 20, y, paint);
        y += 22;
        paint.setFakeBoldText(false);
        paint.setTextSize(12);
        canvas.drawText("Pago:    " + moeda(pago), 20, y, paint);
        y += 18;
        canvas.drawText("Troco:   " + moeda(troco), 20, y, paint);
        y += 26;
        paint.setTextSize(10);
        canvas.drawText("Obrigado pela preferencia!", 20, y, paint);
        y += 16;
        canvas.drawText("Documento nao fiscal", 20, y, paint);

        doc.finishPage(pagina);

        File arquivo = new File(contexto.getCacheDir(),
                "cupom_venda_" + numeroVenda.replaceAll("\\D", "") + ".pdf");
        try (FileOutputStream fos = new FileOutputStream(arquivo)) {
            doc.writeTo(fos);
        } catch (Exception e) {
            doc.close();
            return null;
        }
        doc.close();
        return arquivo;
    }

    private static String cortar(String texto, Paint paint, float maxLargura) {
        while (texto.length() > 4
                && paint.measureText(texto) > maxLargura) {
            texto = texto.substring(0, texto.length() - 1);
        }
        return texto.endsWith(".") ? texto : texto + "..";
    }

    private static String moeda(double valor) {
        return java.text.NumberFormat.getCurrencyInstance(
                new Locale("pt", "BR")).format(valor);
    }
}
