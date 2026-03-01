package com.sirius.s3client.repository;

import android.content.Context;

import androidx.annotation.NonNull;
import androidx.lifecycle.MutableLiveData;
import com.sirius.s3client.API.ApiClient;
import com.sirius.s3client.API.ApiService;
import com.sirius.s3client.dataModel.FileItem;
import com.sirius.s3client.response.ShareLinkResponse;
import java.io.File;
import java.io.IOException;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import okhttp3.MediaType;
import okhttp3.MultipartBody;
import okhttp3.RequestBody;
import okhttp3.ResponseBody;
import retrofit2.Call;
import retrofit2.Callback;
import retrofit2.Response;

public class FileRepository {
    private final ApiService apiService;

    public FileRepository(Context context) {
        apiService = ApiClient.getInstance(context).getApiService();
    }

    public void listFiles(String bucketId, String path,
                          MutableLiveData<List<FileItem>> filesLiveData,
                          MutableLiveData<String> errorLiveData,
                          MutableLiveData<Boolean> loadingLiveData) {
        loadingLiveData.setValue(true);
        apiService.listFiles(bucketId, path).enqueue(new Callback<List<FileItem>>() {
            @Override
            public void onResponse(@NonNull Call<List<FileItem>> call, @NonNull Response<List<FileItem>> response) {
                loadingLiveData.setValue(false);
                if (response.isSuccessful() && response.body() != null) {
                    filesLiveData.setValue(response.body());
                } else {
                    errorLiveData.setValue(getErrorMessage(response));
                }
            }

            @Override
            public void onFailure(@NonNull Call<List<FileItem>> call, @NonNull Throwable t) {
                loadingLiveData.setValue(false);
                errorLiveData.setValue("Network error: " + t.getMessage());
            }
        });
    }

    public void createFolder(String bucketId, String name, String path,
                             MutableLiveData<Boolean> successLiveData,
                             MutableLiveData<String> errorLiveData,
                             MutableLiveData<Boolean> loadingLiveData) {
        Map<String, String> body = new HashMap<>();
        body.put("bucketId", bucketId);
        body.put("name", name);
        body.put("path", path);
        loadingLiveData.setValue(true);
        apiService.createFolder(body).enqueue(new Callback<Void>() {
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

    public void uploadFile(String bucketId, String path, File file,
                           MutableLiveData<FileItem> uploadedLiveData,
                           MutableLiveData<String> errorLiveData,
                           MutableLiveData<Boolean> loadingLiveData) {
        RequestBody bucketBody = RequestBody.create(MediaType.parse("text/plain"), bucketId);
        RequestBody pathBody = RequestBody.create(MediaType.parse("text/plain"), path);
        RequestBody fileBody = RequestBody.create(MediaType.parse("*/*"), file);
        MultipartBody.Part part = MultipartBody.Part.createFormData("file", file.getName(), fileBody);

        loadingLiveData.setValue(true);
        apiService.uploadFile(bucketBody, pathBody, part).enqueue(new Callback<FileItem>() {
            @Override
            public void onResponse(@NonNull Call<FileItem> call, @NonNull Response<FileItem> response) {
                loadingLiveData.setValue(false);
                if (response.isSuccessful() && response.body() != null) {
                    uploadedLiveData.setValue(response.body());
                } else {
                    errorLiveData.setValue(getErrorMessage(response));
                }
            }

            @Override
            public void onFailure(@NonNull Call<FileItem> call, @NonNull Throwable t) {
                loadingLiveData.setValue(false);
                errorLiveData.setValue("Network error: " + t.getMessage());
            }
        });
    }

    public void downloadFile(String fileId,
                             MutableLiveData<ResponseBody> downloadedLiveData,
                             MutableLiveData<String> errorLiveData,
                             MutableLiveData<Boolean> loadingLiveData) {
        loadingLiveData.setValue(true);
        apiService.downloadFile(fileId).enqueue(new Callback<ResponseBody>() {
            @Override
            public void onResponse(@NonNull Call<ResponseBody> call, @NonNull Response<ResponseBody> response) {
                loadingLiveData.setValue(false);
                if (response.isSuccessful() && response.body() != null) {
                    downloadedLiveData.setValue(response.body());
                } else {
                    errorLiveData.setValue(getErrorMessage(response));
                }
            }

            @Override
            public void onFailure(@NonNull Call<ResponseBody> call, @NonNull Throwable t) {
                loadingLiveData.setValue(false);
                errorLiveData.setValue("Network error: " + t.getMessage());
            }
        });
    }

    public void deleteItem(String itemId,
                           MutableLiveData<Boolean> successLiveData,
                           MutableLiveData<String> errorLiveData,
                           MutableLiveData<Boolean> loadingLiveData) {
        loadingLiveData.setValue(true);
        apiService.deleteItem(itemId).enqueue(new Callback<Void>() {
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

    public void moveItem(String itemId, String targetBucketId, String targetPath,
                         MutableLiveData<Boolean> successLiveData,
                         MutableLiveData<String> errorLiveData,
                         MutableLiveData<Boolean> loadingLiveData) {
        Map<String, String> body = new HashMap<>();
        body.put("id", itemId);
        body.put("targetBucketId", targetBucketId);
        body.put("targetPath", targetPath);
        loadingLiveData.setValue(true);
        apiService.moveItem(body).enqueue(new Callback<Void>() {
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

    public void createShareLink(String itemId,
                                MutableLiveData<ShareLinkResponse> linkLiveData,
                                MutableLiveData<String> errorLiveData,
                                MutableLiveData<Boolean> loadingLiveData) {
        Map<String, String> body = new HashMap<>();
        body.put("id", itemId);
        loadingLiveData.setValue(true);
        apiService.createShareLink(body).enqueue(new Callback<ShareLinkResponse>() {
            @Override
            public void onResponse(@NonNull Call<ShareLinkResponse> call, @NonNull Response<ShareLinkResponse> response) {
                loadingLiveData.setValue(false);
                if (response.isSuccessful() && response.body() != null) {
                    linkLiveData.setValue(response.body());
                } else {
                    errorLiveData.setValue(getErrorMessage(response));
                }
            }

            @Override
            public void onFailure(@NonNull Call<ShareLinkResponse> call, @NonNull Throwable t) {
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