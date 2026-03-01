package com.sirius.s3client.dataModel;

import com.google.gson.annotations.SerializedName;

import java.util.Locale;

public class FileItem {
    @SerializedName("id")
    private String id;

    @SerializedName("name")
    private String name;

    @SerializedName("type")
    private String type;

    @SerializedName("size")
    private long size;

    @SerializedName("modifiedAt")
    private String modifiedAt;

    @SerializedName("path")
    private String path;

    @SerializedName("mimeType")
    private String mimeType;

    public FileItem(String id, String name, String type, long size, String modifiedAt, String path, String mimeType) {
        this.id = id;
        this.name = name;
        this.type = type;
        this.size = size;
        this.modifiedAt = modifiedAt;
        this.path = path;
        this.mimeType = mimeType;
    }

    public String getModifiedAt() {
        return modifiedAt;
    }

    public String getPath() {
        return path;
    }

    public String getId() {
        return id;
    }

    public String getName() {
        return name;
    }

    public String getMimeType() {
        return mimeType;
    }

    public boolean isFolder(){
        return "folder".equals(type);
    }

    public String getFormattedSize() {
        if (size < 1024) return size + " B";
        int exp = (int) (Math.log(size) / Math.log(1024));
        String pre = "KMGTPE".charAt(exp-1) + "";
        return String.format(Locale.ENGLISH,"%.1f %sB", size / Math.pow(1024, exp), pre);
    }
}
