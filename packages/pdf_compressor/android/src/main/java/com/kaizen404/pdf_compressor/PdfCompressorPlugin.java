package com.kaizen404.pdf_compressor;

import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Canvas;
import android.graphics.Matrix;
import android.graphics.Paint;
import androidx.annotation.NonNull;
import com.itextpdf.text.pdf.PRStream;
import com.itextpdf.text.pdf.PdfName;
import com.itextpdf.text.pdf.PdfNumber;
import com.itextpdf.text.pdf.PdfObject;
import com.itextpdf.text.pdf.PdfReader;
import com.itextpdf.text.pdf.PdfStamper;
import com.itextpdf.text.pdf.parser.PdfImageObject;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import java.io.ByteArrayOutputStream;
import java.io.FileOutputStream;

/** PdfCompressorPlugin */
public class PdfCompressorPlugin implements FlutterPlugin, MethodCallHandler {

  private MethodChannel channel;

  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
    channel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), "pdf_compressor");
    channel.setMethodCallHandler(this);
  }

  @Override
  public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
    switch (call.method) {
      case "compressPdf":
        String inputPath = call.argument("inputPath").toString();
        String outputPath = call.argument("outputPath").toString();
        int quality = call.argument("quality");
        int maxWidth = call.argument("maxWidth");
        int maxHeight = call.argument("maxHeight");
        boolean resizeImages = call.argument("resizeImages");
        try {
          new CompressPdf(inputPath, outputPath, quality, maxWidth, maxHeight, resizeImages).run();
        } catch (Exception e) {
          e.printStackTrace();
        }
        result.success("success");
        break;
      default:
        result.notImplemented();
    }
  }

  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    channel.setMethodCallHandler(null);
  }

  // Main functionality
  private class CompressPdf {

    String inputPath;
    String outputPath;
    int quality;
    int maxWidth;
    int maxHeight;
    boolean resizeImages;
    final int compressionLevel = 9;

    CompressPdf(String inputPath, String outputPath, int quality, int maxWidth, int maxHeight, boolean resizeImages) {
      this.inputPath = inputPath;
      this.outputPath = outputPath;
      this.quality = quality;
      this.maxWidth = maxWidth;
      this.maxHeight = maxHeight;
      this.resizeImages = resizeImages;
    }

    public void run() throws Exception {
      PdfReader reader = new PdfReader(this.inputPath);
      optimizeAllXrefObjectsFromReader(reader);
      reader.removeUnusedObjects();
      reader.removeFields();
      saveCompressedPdfFromReader(reader);
      reader.close();
    }

    private void saveCompressedPdfFromReader(PdfReader reader) throws Exception {
      PdfStamper stamper = new PdfStamper(reader, new FileOutputStream(this.outputPath));
      stamper.setFullCompression();
      stamper.close();
    }

    private void optimizeAllXrefObjectsFromReader(PdfReader reader) throws Exception {
      int xrefSize = reader.getXrefSize();
      for (int iter = 1; iter <= xrefSize; iter++) {
        PdfObject pdfObject = reader.getPdfObject(iter);

        if (!objectIsStream(pdfObject)) {
          continue;
        }

        PRStream pRStream = (PRStream) pdfObject;

        if (subtypeIsImage(pRStream)) {
          compressXrefImageFromPRStream2(pRStream);
        }
      }
    }

    /**
     * 
     * @param pRStream
     * @throws Exception
     */
    private void compressXrefImageFromPRStream(PRStream pRStream) throws Exception {
      byte[] imageAsBytes = new PdfImageObject(pRStream).getImageAsBytes();
      Bitmap imageBitmap = BitmapFactory.decodeByteArray(imageAsBytes, 0, imageAsBytes.length);

      if (imageBitmap != null) {
        int width = imageBitmap.getWidth();
        int height = imageBitmap.getHeight();

        Bitmap outputImageBitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888);
        new Canvas(outputImageBitmap).drawBitmap(imageBitmap, 0.0f, 0.0f, (Paint) null);
        if (!imageBitmap.isRecycled()) {
          imageBitmap.recycle();
        }

        ByteArrayOutputStream outputImageStream = new ByteArrayOutputStream();
        outputImageBitmap.compress(Bitmap.CompressFormat.JPEG, this.quality, outputImageStream);
        if (!outputImageBitmap.isRecycled()) {
          outputImageBitmap.recycle();
        }

        resetPRStreamForImage(pRStream, outputImageStream.toByteArray(), width, height);
        outputImageStream.close();
      }
    }

    /**
     * 
     * @param pRStream
     * @throws Exception
     */
    private void compressXrefImageFromPRStream2(PRStream pRStream) throws Exception {
      byte[] imageAsBytes = new PdfImageObject(pRStream).getImageAsBytes();
      ByteArrayOutputStream outputImageStream = new ByteArrayOutputStream();

      Bitmap resultBitmap = compressImage(imageAsBytes, quality, outputImageStream);

      int width = resultBitmap.getWidth();
      int height = resultBitmap.getHeight();

      resetPRStreamForImage(pRStream, outputImageStream.toByteArray(), width, height);
      outputImageStream.close();
    }

    private void resetPRStreamForImage(PRStream stream, byte[] data, int width, int height) {
      stream.clear();
      stream.setData(data, false, this.compressionLevel);
      stream.put(PdfName.TYPE, PdfName.XOBJECT);
      stream.put(PdfName.SUBTYPE, PdfName.IMAGE);
      stream.put(PdfName.FILTER, PdfName.DCTDECODE);
      stream.put(PdfName.WIDTH, new PdfNumber(width));
      stream.put(PdfName.HEIGHT, new PdfNumber(height));
      stream.put(PdfName.BITSPERCOMPONENT, new PdfNumber(8));
      stream.put(PdfName.COLORSPACE, PdfName.DEVICERGB);
    }

    private boolean subtypeIsImage(PRStream stream) {
      PdfObject object = stream.get(PdfName.SUBTYPE);
      return (object != null && object.toString().equals(PdfName.IMAGE.toString()));
    }

    private boolean objectIsStream(PdfObject object) {
      return (object != null && object.isStream());
    }

    /**
     * Compress an image with configurable quality and size limits
     *
     * @param imageAsBytes Original image bytes
     * @param quality JPEG compression quality (1-100)
     * @param outputImageStream Output stream to write compressed image
     * @throws Exception
     */
    private Bitmap compressImage(byte[] imageAsBytes, int quality, ByteArrayOutputStream outputImageStream)
        throws Exception {
      Bitmap scaledBitmap = null;

      BitmapFactory.Options options = new BitmapFactory.Options();

      // First pass: get image dimensions without loading pixels
      options.inJustDecodeBounds = true;
      BitmapFactory.decodeByteArray(imageAsBytes, 0, imageAsBytes.length, options);

      int actualHeight = options.outHeight;
      int actualWidth = options.outWidth;

      // Use dynamic max dimensions based on compression level
      float maxHeightF = (float) this.maxHeight;
      float maxWidthF = (float) this.maxWidth;

      // Only resize if resizeImages is enabled and image exceeds max dimensions
      if (this.resizeImages && (actualHeight > maxHeightF || actualWidth > maxWidthF)) {
        float imgRatio = (float) actualWidth / (float) actualHeight;
        float maxRatio = maxWidthF / maxHeightF;

        // Maintain aspect ratio while fitting within max dimensions
        if (imgRatio < maxRatio) {
          imgRatio = maxHeightF / actualHeight;
          actualWidth = (int) (imgRatio * actualWidth);
          actualHeight = (int) maxHeightF;
        } else if (imgRatio > maxRatio) {
          imgRatio = maxWidthF / actualWidth;
          actualHeight = (int) (imgRatio * actualHeight);
          actualWidth = (int) maxWidthF;
        } else {
          actualHeight = (int) maxHeightF;
          actualWidth = (int) maxWidthF;
        }
      }

      // Calculate sample size for efficient memory usage
      options.inSampleSize = calculateInSampleSize(options, actualWidth, actualHeight);

      // Second pass: load the actual bitmap
      options.inJustDecodeBounds = false;
      options.inPurgeable = true;
      options.inInputShareable = true;
      options.inTempStorage = new byte[16 * 1024];

      Bitmap bmp = BitmapFactory.decodeByteArray(imageAsBytes, 0, imageAsBytes.length, options);

      if (bmp == null) {
        throw new Exception("Failed to decode image");
      }

      scaledBitmap = Bitmap.createBitmap(actualWidth, actualHeight, Bitmap.Config.ARGB_8888);

      float ratioX = actualWidth / (float) options.outWidth;
      float ratioY = actualHeight / (float) options.outHeight;
      float middleX = actualWidth / 2.0f;
      float middleY = actualHeight / 2.0f;

      Matrix scaleMatrix = new Matrix();
      scaleMatrix.setScale(ratioX, ratioY, middleX, middleY);

      Canvas canvas = new Canvas(scaledBitmap);
      canvas.setMatrix(scaleMatrix);
      canvas.drawBitmap(bmp, middleX - bmp.getWidth() / 2, middleY - bmp.getHeight() / 2,
          new Paint(Paint.FILTER_BITMAP_FLAG));

      // Clean up original bitmap
      if (!bmp.isRecycled()) {
        bmp.recycle();
      }

      // Compress to JPEG with specified quality
      scaledBitmap.compress(Bitmap.CompressFormat.JPEG, quality, outputImageStream);
      return scaledBitmap;
    }

    private int calculateInSampleSize(BitmapFactory.Options options, int reqWidth, int reqHeight) {
      final int height = options.outHeight;
      final int width = options.outWidth;
      int inSampleSize = 1;

      if (height > reqHeight || width > reqWidth) {
        final int heightRatio = Math.round((float) height / (float) reqHeight);
        final int widthRatio = Math.round((float) width / (float) reqWidth);
        inSampleSize = heightRatio < widthRatio ? heightRatio : widthRatio;
      }
      final float totalPixels = width * height;
      final float totalReqPixelsCap = reqWidth * reqHeight * 2;
      while (totalPixels / (inSampleSize * inSampleSize) > totalReqPixelsCap) {
        inSampleSize++;
      }

      return inSampleSize;
    }

  }
}
