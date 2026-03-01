package com.sirius.s3client.API;

import android.content.Context;
import com.sirius.s3client.BuildConfig;

import com.sirius.s3client.security.SecurePrefs;
import java.util.concurrent.TimeUnit;
import okhttp3.Interceptor;
import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.logging.HttpLoggingInterceptor;
import retrofit2.Retrofit;
import retrofit2.converter.gson.GsonConverterFactory;

public class ApiClient {
    private static final String BASE_URL = BuildConfig.BASE_URL;
    private static ApiClient instance;
    private final Retrofit retrofit;
    private final SecurePrefs securePrefs;

    private ApiClient(Context context) {
        securePrefs = new SecurePrefs(context);

        HttpLoggingInterceptor logging = new HttpLoggingInterceptor();
        logging.setLevel(HttpLoggingInterceptor.Level.NONE);

        Interceptor authInterceptor = chain -> {
            Request original = chain.request();
            Request.Builder builder = original.newBuilder();
            String session = securePrefs.getSessionToken();
            String csrf = securePrefs.getCsrfToken();
            if (session != null) builder.addHeader("X-Session-Token", session);
            if (csrf != null) builder.addHeader("X-CSRF-Token", csrf);
            builder.addHeader("Content-Type", "application/json");
            builder.addHeader("Accept", "application/json");
            return chain.proceed(builder.build());
        };

        OkHttpClient client = new OkHttpClient.Builder()
                .addInterceptor(logging)
                .addInterceptor(authInterceptor)
                .connectTimeout(30, TimeUnit.SECONDS)
                .readTimeout(30, TimeUnit.SECONDS)
                .writeTimeout(30, TimeUnit.SECONDS)
                .build();

        retrofit = new Retrofit.Builder()
                .baseUrl(BASE_URL)
                .client(client)
                .addConverterFactory(GsonConverterFactory.create())
                .build();
    }

    public static synchronized ApiClient getInstance(Context context) {
        if (instance == null) {
            instance = new ApiClient(context.getApplicationContext());
        }
        return instance;
    }

    public ApiService getApiService() {
        return retrofit.create(ApiService.class);
    }
}