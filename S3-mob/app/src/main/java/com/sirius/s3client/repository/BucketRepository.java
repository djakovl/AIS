package com.sirius.s3client.repository;

import android.content.Context;

import androidx.annotation.NonNull;
import androidx.lifecycle.MutableLiveData;
import com.sirius.s3client.API.ApiClient;
import com.sirius.s3client.API.ApiService;
import com.sirius.s3client.dataModel.Bucket;
import java.io.IOException;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import retrofit2.Call;
import retrofit2.Callback;
import retrofit2.Response;

public class BucketRepository {
    private final ApiService apiService;

    public BucketRepository(Context context) {
        apiService = ApiClient.getInstance(context).getApiService();
    }

    public void listBuckets(MutableLiveData<List<Bucket>> bucketsLiveData,
                            MutableLiveData<String> errorLiveData,
                            MutableLiveData<Boolean> loadingLiveData) {
        loadingLiveData.setValue(true);
        apiService.listBuckets().enqueue(new Callback<List<Bucket>>() {
            @Override
            public void onResponse(@NonNull Call<List<Bucket>> call, @NonNull Response<List<Bucket>> response) {
                loadingLiveData.setValue(false);
                if (response.isSuccessful() && response.body() != null) {
                    bucketsLiveData.setValue(response.body());
                } else {
                    errorLiveData.setValue(getErrorMessage(response));
                }
            }

            @Override
            public void onFailure(@NonNull Call<List<Bucket>> call, @NonNull Throwable t) {
                loadingLiveData.setValue(false);
                errorLiveData.setValue("Network error: " + t.getMessage());
            }
        });
    }

    public void createBucket(String name,
                             MutableLiveData<Boolean> successLiveData,
                             MutableLiveData<String> errorLiveData,
                             MutableLiveData<Boolean> loadingLiveData) {
        Map<String, String> body = new HashMap<>();
        body.put("name", name);
        loadingLiveData.setValue(true);
        apiService.createBucket(body).enqueue(new Callback<Void>() {
            @Override
            public void onResponse(@NonNull Call<Void> call, @NonNull Response<Void> response) {
                loadingLiveData.setValue(false);
                if (response.isSuccessful()) {
                    successLiveData.setValue(true);
                } else {
                    errorLiveData.setValue(getErrorMessage(response));
                }
            }

            @Override
            public void onFailure(@NonNull Call<Void> call, @NonNull Throwable t) {
                loadingLiveData.setValue(false);
                errorLiveData.setValue("Network error: " + t.getMessage());
            }
        });
    }

    public void deleteBucket(String id,
                             MutableLiveData<Boolean> successLiveData,
                             MutableLiveData<String> errorLiveData,
                             MutableLiveData<Boolean> loadingLiveData) {
        loadingLiveData.setValue(true);
        apiService.deleteBucket(id).enqueue(new Callback<Void>() {
            @Override
            public void onResponse(@NonNull Call<Void> call, @NonNull Response<Void> response) {
                loadingLiveData.setValue(false);
                if (response.isSuccessful()) {
                    successLiveData.setValue(true);
                } else {
                    errorLiveData.setValue(getErrorMessage(response));
                }
            }

            @Override
            public void onFailure(@NonNull Call<Void> call, @NonNull Throwable t) {
                loadingLiveData.setValue(false);
                errorLiveData.setValue("Network error: " + t.getMessage());
            }
        });
    }

    private String getErrorMessage(Response<?> response) {
        try {
            if (response.errorBody() != null) {
                return response.errorBody().string();
            }
        } catch (IOException ignored) {}
        return "Error " + response.code();
    }
}