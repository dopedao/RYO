package graph

// This file will be automatically regenerated based on the schema, any resolver implementations
// will be copied through when generating and any unknown code will be moved to the end.

import (
	"context"

	"github.com/dopedao/RYO/api/ent"
	"github.com/dopedao/RYO/api/graph/generated"
)

func (r *queryResolver) Turns(ctx context.Context) ([]*ent.Turn, error) {
	return r.client.Turn.Query().All(ctx)
}

// Query returns generated.QueryResolver implementation.
func (r *Resolver) Query() generated.QueryResolver { return &queryResolver{r} }

type queryResolver struct{ *Resolver }
