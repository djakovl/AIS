package middleware

import "context"

type contextKey string

const (
	CtxUserID    contextKey = "user_id"
	CtxRoles     contextKey = "roles"
	CtxCSRFToken contextKey = "csrf_token"
	CtxSessionID contextKey = "session_id"
)

func ctxSet(ctx context.Context, key contextKey, value string) context.Context {
	return context.WithValue(ctx, key, value)
}

func CtxGet(ctx context.Context, key contextKey) string {
	if v, ok := ctx.Value(key).(string); ok {
		return v
	}
	return ""
}
