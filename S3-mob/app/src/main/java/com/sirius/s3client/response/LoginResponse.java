package com.sirius.s3client.response;

import com.google.gson.annotations.SerializedName;

public class LoginResponse {
    @SerializedName("sessionToken")
    private String sessionToken;

    @SerializedName("csrfToken")
    private String csrfToken;

    @SerializedName("userId")
    private String userId;
    public String getSessionToken() { return sessionToken; }
    public String getCsrfToken() { return csrfToken; }
    public String getUserId() { return userId; }
}