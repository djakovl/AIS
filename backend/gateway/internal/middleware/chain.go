package middleware

import "net/http"

// Chain применяет middleware справа налево:
// Chain(h, A, B, C) => A(B(C(h)))
func Chain(h http.Handler, mws ...func(http.Handler) http.Handler) http.Handler {
	for i := len(mws) - 1; i >= 0; i-- {
		h = mws[i](h)
	}
	return h
}
