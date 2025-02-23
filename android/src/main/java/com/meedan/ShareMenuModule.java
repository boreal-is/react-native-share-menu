package com.meedan;

import com.borealis.borealis.vcard.VCardData;
import com.borealis.borealis.vcard.VCardHandler;
import com.facebook.react.bridge.ActivityEventListener;
import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.bridge.Callback;
import com.facebook.react.bridge.ReadableMap;
import com.facebook.react.bridge.WritableArray;
import com.facebook.react.bridge.WritableMap;
import com.facebook.react.modules.core.DeviceEventManagerModule;

import android.app.Activity;
import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import java.util.ArrayList;
import com.google.gson.Gson;

public class ShareMenuModule extends ReactContextBaseJavaModule implements ActivityEventListener {

  // Events
  final String NEW_SHARE_EVENT = "NewShareEvent";

  // Keys
  final String MIME_TYPE_KEY = "mimeType";
  final String DATA_KEY = "data";
  final String VCARD_KEY = "vcard";
  final String DOCUMENTS_KEY = "documents";
  final String TEXT_KEY = "text";
  final String URL_KEY = "url";

  private ReactContext mReactContext;

  public ShareMenuModule(ReactApplicationContext reactContext) {
    super(reactContext);
    mReactContext = reactContext;

    mReactContext.addActivityEventListener(this);
  }

  @NonNull
  @Override
  public String getName() {
    return "ShareMenu";
  }

  @Nullable
  private ReadableMap extractShared(Intent intent)  {
    String type = intent.getType();

    if (type == null) {
      return null;
    }

    String action = intent.getAction();

    WritableMap finalData = Arguments.createMap();

    if (Intent.ACTION_SEND.equals(action)) {
      WritableMap data = Arguments.createMap();
      WritableArray array = Arguments.createArray();
      if ("text/plain".equals(type)) {
        data.putString(MIME_TYPE_KEY, type);
        data.putString(DATA_KEY, intent.getStringExtra(Intent.EXTRA_TEXT));
        finalData.putMap(TEXT_KEY, data);
        return finalData;
      } else if ("text/x-vcard".equals(type)) {
        Bundle extras = intent.getExtras();
        Gson gson = new Gson();
        VCardHandler handler = new VCardHandler(mReactContext);
        VCardData vCard = handler.processVCard(extras);
        if (vCard != null) {
          data.putString(DATA_KEY, gson.toJson(vCard));
          data.putString(MIME_TYPE_KEY, "application/json");
          finalData.putMap(VCARD_KEY, data);
          return finalData;
        }
      } else {
        Uri fileUri = intent.getParcelableExtra(Intent.EXTRA_STREAM);
        if (fileUri != null) {
          data.putString(MIME_TYPE_KEY, mReactContext.getContentResolver().getType(fileUri));
          data.putString(URL_KEY, fileUri.toString());
          array.pushMap(data);
          finalData.putArray(DOCUMENTS_KEY, array);
          return finalData;
        }
      }
    } else if (Intent.ACTION_SEND_MULTIPLE.equals(action)) {
      ArrayList<Uri> fileUris = intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM);
      if (fileUris != null) {
        WritableArray uriArr = Arguments.createArray();
        for (Uri uri : fileUris) {
          WritableMap data = Arguments.createMap();
          data.putString(URL_KEY, uri.toString());
          data.putString(MIME_TYPE_KEY, mReactContext.getContentResolver().getType(uri));
          uriArr.pushMap(data);
        }
        finalData.putArray(DOCUMENTS_KEY, uriArr);
        return finalData;
      }
    }

    return null;
  }

  @ReactMethod
  public void getSharedText(Callback successCallback) {
    Activity currentActivity = getCurrentActivity();

    if (currentActivity == null) {
      return;
    }

    Intent intent = currentActivity.getIntent();

    ReadableMap shared = extractShared(intent);
    successCallback.invoke(shared);
    clearSharedText();
  }

  private void dispatchEvent(ReadableMap shared) {
    if (mReactContext == null || !mReactContext.hasActiveCatalystInstance()) {
      return;
    }

    mReactContext
            .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class)
            .emit(NEW_SHARE_EVENT, shared);
  }

  public void clearSharedText() {
    Activity mActivity = getCurrentActivity();
    
    if(mActivity == null) { return; }

    Intent intent = mActivity.getIntent();
    String type = intent.getType();

    if (type == null) {
      return;
    }

    if ("text/plain".equals(type)) {
      intent.removeExtra(Intent.EXTRA_TEXT);
      return;
    }

    intent.removeExtra(Intent.EXTRA_STREAM);
  }

  @Override
  public void onActivityResult(Activity activity, int requestCode, int resultCode, Intent data) {
    // DO nothing
  }

  @Override
  public void onNewIntent(Intent intent) {
    // Possibly received a new share while the app was already running

    Activity currentActivity = getCurrentActivity();

    if (currentActivity == null) {
      return;
    }

    ReadableMap shared = extractShared(intent);
    dispatchEvent(shared);

    // Update intent in case the user calls `getSharedText` again
    currentActivity.setIntent(intent);
  }
}
