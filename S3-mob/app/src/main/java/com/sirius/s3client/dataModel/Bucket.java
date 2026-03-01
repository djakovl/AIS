package com.sirius.s3client.dataModel;

import com.google.gson.annotations.SerializedName;

import java.util.Date;

public class Bucket {
    @SerializedName("id")
    private String id;
    @SerializedName("name")
    private String name;
    @SerializedName("createdAt")
    private Date createdAt;

    public Bucket(String id, String name, Date createdAt){
        this.id = id;
        this.name = name;
        this.createdAt = createdAt;
    }

    public String getCreationDate() {
        return createdAt.toString();
    }

    public String getName() {
        return name;
    }

    public String getId(){
        return id;
    }
}
