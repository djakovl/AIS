package com.sirius.s3client.security;

import android.content.Context;
import android.content.SharedPreferences;
import androidx.security.crypto.EncryptedSharedPreferences;
import androidx.security.crypto.MasterKey;

import com.sirius.s3client.BuildConfig;

import java.io.IOException;
import java.security.GeneralSecurityException;

public class SecurePrefs {
    private static final String PREFS_NAME = BuildConfig.PREFS_NAME;
    private static final String KEY_SESSION = BuildConfig.KEY_SESSION;
    private static final String KEY_CSRF = BuildConfig.KEY_CSRF;

    private final SharedPreferences prefs;

    public SecurePrefs(Context context) {
        try {
            MasterKey masterKey = new MasterKey.Builder(context)
                    .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
                    .build();

            prefs = EncryptedSharedPreferences.create(
                    context,
                    PREFS_NAME,
                    masterKey,
                    EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
                    EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
            );
        } catch (GeneralSecurityException | IOException e) {
            throw new RuntimeException("Failed to create encrypted prefs", e);
        }
    }

    public void saveTokens(String sessionToken, String csrfToken) {
        prefs.edit()
                .putString(KEY_SESSION, sessionToken)
                .putString(KEY_CSRF, csrfToken)
                .apply();
    }

    public String getSessionToken() {
        return prefs.getString(KEY_SESSION, null);
    }

    public String getCsrfToken() {
        return prefs.getString(KEY_CSRF, null);
    }

    public void clear() {
        prefs.edit().clear().apply();
    }
}
