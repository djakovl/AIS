package com.sirius.s3client.viewModel;

import android.app.Application;
import androidx.annotation.NonNull;
import androidx.lifecycle.AndroidViewModel;
import androidx.lifecycle.LiveData;
import androidx.lifecycle.MutableLiveData;
import com.sirius.s3client.dataModel.FileItem;
import com.sirius.s3client.response.ShareLinkResponse;
import com.sirius.s3client.repository.FileRepository;
import java.io.File;
import java.util.List;
import okhttp3.ResponseBody;

public class ObjectsViewModel extends AndroidViewModel {
    private final FileRepository repository;
    private final MutableLiveData<List<FileItem>> files = new MutableLiveData<>();
    private final MutableLiveData<String> currentPath = new MutableLiveData<>("");
    private final MutableLiveData<String> error = new MutableLiveData<>();
    private final MutableLiveData<Boolean> loading = new MutableLiveData<>(false);
    private final MutableLiveData<Boolean> operationSuccess = new MutableLiveData<>(false);
    private final MutableLiveData<FileItem> uploadedFile = new MutableLiveData<>();
    private final MutableLiveData<ResponseBody> downloadedFile = new MutableLiveData<>();
    private final MutableLiveData<ShareLinkResponse> shareLink = new MutableLiveData<>();

    private String bucketId;

    public ObjectsViewModel(@NonNull Application application) {
        super(application);
        repository = new FileRepository(application);
    }

    public void setBucketId(String bucketId) { this.bucketId = bucketId; }
    public LiveData<List<FileItem>> getFiles() { return files; }
    public LiveData<String> getCurrentPath() { return currentPath; }
    public LiveData<String> getError() { return error; }
    public LiveData<Boolean> getLoading() { return loading; }
    public LiveData<Boolean> getOperationSuccess() { return operationSuccess; }
    public LiveData<FileItem> getUploadedFile() { return uploadedFile; }
    public LiveData<ResponseBody> getDownloadedFile() { return downloadedFile; }
    public LiveData<ShareLinkResponse> getShareLink() { return shareLink; }

    public void loadFiles(String path) {
        if (bucketId == null) return;
        currentPath.setValue(path);
        repository.listFiles(bucketId, path, files, error, loading);
    }

    public void navigateUp() {
        String path = currentPath.getValue();
        if (path == null || path.isEmpty()) return;
        int lastSlash = path.lastIndexOf('/');
        String parent = lastSlash > 0 ? path.substring(0, lastSlash) : "";
        loadFiles(parent);
    }

    public void createFolder(String name) {
        if (bucketId == null) return;
        repository.createFolder(bucketId, name, currentPath.getValue(), operationSuccess, error, loading);
    }

    public void uploadFile(File file) {
        if (bucketId == null) return;
        repository.uploadFile(bucketId, currentPath.getValue(), file, uploadedFile, error, loading);
    }

    public void downloadFile(String fileId) {
        repository.downloadFile(fileId, downloadedFile, error, loading);
    }

    public void deleteItem(String itemId) {
        repository.deleteItem(itemId, operationSuccess, error, loading);
    }

    public void moveItem(String itemId, String targetBucketId, String targetPath) {
        repository.moveItem(itemId, targetBucketId, targetPath, operationSuccess, error, loading);
    }

    public void createShareLink(String itemId) {
        repository.createShareLink(itemId, shareLink, error, loading);
    }

    public void resetOperationSuccess() {
        operationSuccess.setValue(false);
    }

    public void clearShareLink() {
        shareLink.setValue(null);
    }

    public void clearDownloadedFile() {
        downloadedFile.setValue(null);
    }
}