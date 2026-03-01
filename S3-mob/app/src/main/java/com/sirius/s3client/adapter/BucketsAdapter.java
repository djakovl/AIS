package com.sirius.s3client.adapter;

import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ImageView;
import android.widget.PopupMenu;
import android.widget.TextView;
import androidx.annotation.NonNull;
import androidx.recyclerview.widget.RecyclerView;
import com.sirius.s3client.R;
import com.sirius.s3client.dataModel.Bucket;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.List;
import java.util.Locale;

public class BucketsAdapter extends RecyclerView.Adapter<BucketsAdapter.ViewHolder> {
    private List<Bucket> buckets;
    private final OnBucketActionListener listener;

    public void setBuckets(List<Bucket> buckets) {
        this.buckets = buckets;
    }

    public interface OnBucketActionListener {
        void onBucketClick(Bucket bucket);
        void onBucketDelete(Bucket bucket);
        void onBucketShare(Bucket bucket);
    }

    public BucketsAdapter(List<Bucket> buckets, OnBucketActionListener listener) {
        this.buckets = buckets;
        this.listener = listener;
    }

    @NonNull
    @Override
    public ViewHolder onCreateViewHolder(@NonNull ViewGroup parent, int viewType) {
        View view = LayoutInflater.from(parent.getContext()).inflate(R.layout.item_bucket, parent, false);
        return new ViewHolder(view);
    }

    @Override
    public void onBindViewHolder(@NonNull ViewHolder holder, int position) {
        Bucket bucket = buckets.get(position);
        holder.tvName.setText(bucket.getName());
        if (bucket.getCreationDate() != null) {
            holder.tvCreated.setVisibility(View.VISIBLE);
            holder.tvCreated.setText(formatDate(bucket.getCreationDate()));
        } else {
            holder.tvCreated.setVisibility(View.GONE);
        }
        holder.itemView.setOnClickListener(v -> {
            if (listener != null) listener.onBucketClick(bucket);
        });
        holder.ivMore.setOnClickListener(v -> showPopupMenu(v, bucket));
    }

    @Override
    public int getItemCount() { return buckets.size(); }

    private void showPopupMenu(View anchor, Bucket bucket) {
        PopupMenu popup = new PopupMenu(anchor.getContext(), anchor);
        popup.getMenuInflater().inflate(R.menu.menu_bucket, popup.getMenu());
        popup.setOnMenuItemClickListener(item -> {
            int id = item.getItemId();
            if (id == R.id.action_delete && listener != null) {
                listener.onBucketDelete(bucket);
                return true;
            } else if (id == R.id.action_share && listener != null) {
                listener.onBucketShare(bucket);
                return true;
            }
            return false;
        });
        popup.show();
    }

    private String formatDate(String dateStr) {
        try {
            SimpleDateFormat input = new SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.US);
            SimpleDateFormat output = new SimpleDateFormat("dd MMM yyyy", Locale.getDefault());
            Date date = input.parse(dateStr);
            assert date != null;
            return output.format(date);
        } catch (Exception e) {
            return dateStr;
        }
    }

    static class ViewHolder extends RecyclerView.ViewHolder {
        TextView tvName, tvCreated;
        ImageView ivMore;
        ViewHolder(@NonNull View itemView) {
            super(itemView);
            tvName = itemView.findViewById(R.id.tv_bucket_name);
            tvCreated = itemView.findViewById(R.id.tv_bucket_created);
            ivMore = itemView.findViewById(R.id.iv_bucket_more);
        }
    }
}