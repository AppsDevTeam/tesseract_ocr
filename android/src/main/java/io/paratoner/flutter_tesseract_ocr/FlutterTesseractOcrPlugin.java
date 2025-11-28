package io.paratoner.flutter_tesseract_ocr;

import com.googlecode.tesseract.android.TessBaseAPI;

import android.os.AsyncTask;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import androidx.annotation.NonNull;

import java.io.File;
import java.util.Map.*;
import java.util.Map;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;

public class FlutterTesseractOcrPlugin implements FlutterPlugin, MethodCallHandler {
  private static final int DEFAULT_PAGE_SEG_MODE = TessBaseAPI.PageSegMode.PSM_AUTO_OSD;
  private TessBaseAPI baseApi = null;
  private String lastLanguage = "";

  private MethodChannel channel;

  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
    BinaryMessenger messenger = flutterPluginBinding.getBinaryMessenger();
    channel = new MethodChannel(messenger, "flutter_tesseract_ocr");
    channel.setMethodCallHandler(this);
  }

  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    if (channel != null) {
      channel.setMethodCallHandler(null);
      channel = null;
    }
    if (baseApi != null) {
      baseApi.recycle();
      baseApi = null;
    }
  }

  @Override
  public void onMethodCall(final MethodCall call, final Result result) {
    switch (call.method) {
      case "extractText":
      case "extractHocr":
        final String tessDataPath = call.argument("tessData");
        final String imagePath = call.argument("imagePath");
        final byte[] imageBytes = call.argument("imageBytes");
        final Map<String, String> args = call.argument("args");
        String DEFAULT_LANGUAGE = "eng";

        if (call.argument("language") != null) {
          DEFAULT_LANGUAGE = call.argument("language");
        }

        if (baseApi == null || !lastLanguage.equals(DEFAULT_LANGUAGE)) {
          baseApi = new TessBaseAPI();
          baseApi.init(tessDataPath, DEFAULT_LANGUAGE);
          lastLanguage = DEFAULT_LANGUAGE;
        }

        int psm = DEFAULT_PAGE_SEG_MODE;
        if (args != null) {
          for (Map.Entry<String, String> entry : args.entrySet()) {
            if (!entry.getKey().equals("psm")) {
              baseApi.setVariable(entry.getKey(), entry.getValue());
            } else {
              psm = Integer.parseInt(entry.getValue());
            }
          }
        }

        baseApi.setPageSegMode(psm);
        if (imageBytes != null) {
          new OcrAsyncTask(baseApi, imageBytes, result, call.method.equals("extractHocr")).execute();
        } else if (imagePath != null) {
          new OcrAsyncTask(baseApi, new File(imagePath), result, call.method.equals("extractHocr")).execute();
        } else {
          result.error("NO_IMAGE", "Either imagePath or imageBytes must be provided", null);
        }
        break;

      default:
        result.notImplemented();
    }
  }

  private static class OcrAsyncTask extends AsyncTask<Void, Void, String> {
    private final TessBaseAPI baseApi;
    private final File imageFile;
    private final byte[] imageBytes;
    private final Result result;
    private final boolean extractHocr;

    OcrAsyncTask(TessBaseAPI baseApi, File imageFile, Result result, boolean extractHocr) {
      this.baseApi = baseApi;
      this.imageFile = imageFile;
      this.imageBytes = null;
      this.result = result;
      this.extractHocr = extractHocr;
    }

    OcrAsyncTask(TessBaseAPI baseApi, byte[] imageBytes, Result result, boolean extractHocr) {
      this.baseApi = baseApi;
      this.imageFile = null;
      this.imageBytes = imageBytes;
      this.result = result;
      this.extractHocr = extractHocr;
    }

    @Override
    protected String doInBackground(Void... voids) {
      if (imageBytes != null) {
        Bitmap bitmap = BitmapFactory.decodeByteArray(imageBytes, 0, imageBytes.length);

        if (bitmap == null) {
          return "";
        }

        this.baseApi.setImage(bitmap);
      } else if (imageFile != null) {
        this.baseApi.setImage(imageFile);
      } else {
        return "";
      }

      String recognizedText;
      if (extractHocr) {
        recognizedText = this.baseApi.getHOCRText(0);
      } else {
        recognizedText = this.baseApi.getUTF8Text();
      }

      this.baseApi.stop();

      return recognizedText;
    }

    @Override
    protected void onPostExecute(String recognizedText) {
      result.success(recognizedText);
    }
  }
}
