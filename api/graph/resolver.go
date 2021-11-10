package graph

import (
	"github.com/99designs/gqlgen/graphql"
	"github.com/dopedao/RYO/api/ent"
	"github.com/dopedao/RYO/api/graph/generated"
)

type Resolver struct{ client *ent.Client }

// NewSchema creates a graphql executable schema.
func NewSchema(client *ent.Client) graphql.ExecutableSchema {
	return generated.NewExecutableSchema(generated.Config{
		Resolvers: &Resolver{client},
	})
}
