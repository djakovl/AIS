package com.sirius.s3client.response;

import com.google.gson.annotations.SerializedName;

public class ShareLinkResponse {
    @SerializedName("token")
    private String token;

    @SerializedName("url")
    private String url;

    public String getExpiresAt() {
        return expiresAt;
    }

    public String getUrl() {
        return url;
    }

    public String getToken() {
        return token;
    }

    @SerializedName("expiresAt")
    private String expiresAt;

    public ShareLinkResponse(String token, String url, String expiresAt) {
        this.token = token;
        this.url = url;
        this.expiresAt = expiresAt;
    }
}
