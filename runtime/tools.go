//go:build tools
// +build tools

// See https://github.com/golang/go/issues/25922
package runtime

import (
	_ "entgo.io/ent/cmd/ent"
	_ "github.com/99designs/gqlgen"
)
