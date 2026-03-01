package com.sirius.s3client.API;

import com.sirius.s3client.dataModel.Bucket;
import com.sirius.s3client.dataModel.FileItem;
import com.sirius.s3client.request.LoginRequest;
import com.sirius.s3client.request.RegisterRequest;
import com.sirius.s3client.response.LoginResponse;
import com.sirius.s3client.response.RegisterResponse;
import com.sirius.s3client.response.ShareLinkResponse;

import java.util.List;
import java.util.Map;

import okhttp3.MultipartBody;
import okhttp3.RequestBody;
import okhttp3.ResponseBody;
import retrofit2.Call;
import retrofit2.http.Body;
import retrofit2.http.DELETE;
import retrofit2.http.GET;
import retrofit2.http.Multipart;
import retrofit2.http.POST;
import retrofit2.http.Part;
import retrofit2.http.Path;
import retrofit2.http.Query;

public interface ApiService {
    @POST("files/bucket/create")
    Call<Void> createBucket(@Body Map<String, String> body);

    @GET("files/bucket/list")
    Call<List<Bucket>> listBuckets();

    @DELETE("files/bucket/{id}")
    Call<Void> deleteBucket(@Path("id") String bucketId);

    @POST("files/folders/create")
    Call<Void> createFolder(@Body Map<String, String> body);

    @GET("files/list")
    Call<List<FileItem>> listFiles(@Query("bucketId") String bucketId, @Query("path") String path);

    @Multipart
    @POST("files/upload")
    Call<FileItem> uploadFile(@Path("bucketId") RequestBody bucketId,
                              @Path("path") RequestBody path,
                              @Part MultipartBody.Part file);

    @GET("files/download")
    Call<ResponseBody> downloadFile(@Query("id") String fileId);

    @POST("files/mode")
    Call<Void> moveItem(@Body Map<String, String> body);

    @DELETE("files/{id}")
    Call<Void> deleteItem(@Path("id") String itemId);

    @POST("files/share/create")
    Call<ShareLinkResponse> createShareLink(@Body Map<String, String> body);

    @POST("auth/login")
    Call<LoginResponse> login(@Body LoginRequest request);

    @POST("auth/register")
    Call<RegisterResponse> register(@Body RegisterRequest request);
}
