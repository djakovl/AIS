package com.sirius.s3client.viewModel;

import android.app.Application;
import androidx.annotation.NonNull;
import androidx.lifecycle.AndroidViewModel;
import androidx.lifecycle.LiveData;
import androidx.lifecycle.MutableLiveData;
import com.sirius.s3client.dataModel.Bucket;
import com.sirius.s3client.repository.BucketRepository;
import java.util.List;

public class BucketsViewModel extends AndroidViewModel {
    private final BucketRepository repository;
    private final MutableLiveData<List<Bucket>> buckets = new MutableLiveData<>();
    private final MutableLiveData<String> error = new MutableLiveData<>();
    private final MutableLiveData<Boolean> loading = new MutableLiveData<>(false);
    private final MutableLiveData<Boolean> operationSuccess = new MutableLiveData<>(false);

    public BucketsViewModel(@NonNull Application application) {
        super(application);
        repository = new BucketRepository(application);
    }

    public LiveData<List<Bucket>> getBuckets() { return buckets; }
    public LiveData<String> getError() { return error; }
    public LiveData<Boolean> getLoading() { return loading; }
    public LiveData<Boolean> getOperationSuccess() { return operationSuccess; }

    public void loadBuckets() {
        repository.listBuckets(buckets, error, loading);
    }

    public void createBucket(String name) {
        repository.createBucket(name, operationSuccess, error, loading);
    }

    public void deleteBucket(String id) {
        repository.deleteBucket(id, operationSuccess, error, loading);
    }

    public void resetOperationSuccess() {
        operationSuccess.setValue(false);
    }
}