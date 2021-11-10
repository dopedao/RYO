package schema

import (
	"time"

	"entgo.io/contrib/entgql"
	"entgo.io/ent"
	"entgo.io/ent/schema/field"
)

// Turn holds the schema definition for the Turn entity.
type Turn struct {
	ent.Schema
}

// Fields of the Turn.
func (Turn) Fields() []ent.Field {
	return []ent.Field{
		field.String("user_id").
			Immutable().
			NotEmpty().
			Annotations(
				entgql.OrderField("USER_ID"),
			),
		field.String("location_id").
			Immutable().
			NotEmpty().
			Annotations(
				entgql.OrderField("LOCATION_ID"),
			),
		field.String("item_id").
			Immutable().
			NotEmpty().
			Annotations(
				entgql.OrderField("ITEM_ID"),
			),
		field.Bool("buy_or_sell").
			Immutable(),
		field.Int("amount_to_give").
			GoType(BigInt{}).
			SchemaType(BigIntSchemaType),
		field.Ints("user_combat_stats"),
		field.Ints("drug_lord_combat_stats"),
		field.Bool("trade_occurs"),
		field.Int("user_pre_trade_item").
			GoType(BigInt{}).
			SchemaType(BigIntSchemaType),
		field.Int("user_post_trade_pre_event_item").
			GoType(BigInt{}).
			SchemaType(BigIntSchemaType),
		field.Int("user_post_trade_post_event_item").
			GoType(BigInt{}).
			SchemaType(BigIntSchemaType),
		field.Int("user_pre_trade_money").
			GoType(BigInt{}).
			SchemaType(BigIntSchemaType),
		field.Int("user_post_trade_pre_event_money").
			GoType(BigInt{}).
			SchemaType(BigIntSchemaType),
		field.Int("user_post_trade_post_event_money").
			GoType(BigInt{}).
			SchemaType(BigIntSchemaType),
		field.Int("market_pre_trade_item").
			GoType(BigInt{}).
			SchemaType(BigIntSchemaType),
		field.Int("market_post_trade_pre_event_item").
			GoType(BigInt{}).
			SchemaType(BigIntSchemaType),
		field.Int("market_post_trade_post_event_item").
			GoType(BigInt{}).
			SchemaType(BigIntSchemaType),
		field.Int("market_pre_tradeMoney").
			GoType(BigInt{}).
			SchemaType(BigIntSchemaType),
		field.Int("market_post_trade_pre_eventMoney").
			GoType(BigInt{}).
			SchemaType(BigIntSchemaType),
		field.Int("market_post_trade_post_eventMoney").
			GoType(BigInt{}).
			SchemaType(BigIntSchemaType),
		field.Bool("dealer_dash"),
		field.Bool("wrangle_dashed_dealer"),
		field.Bool("mugging"),
		field.Bool("run_from_mugging"),
		field.Bool("gang_war"),
		field.Bool("defend_gang_war"),
		field.Bool("cop_raid"),
		field.Bool("bribe_cops"),
		field.Bool("find_item"),
		field.Bool("local_shipment"),
		field.Bool("warehouse_seizure"),
		field.Time("created_at").
			Default(time.Now).
			Immutable().
			Annotations(
				entgql.OrderField("CREATED_AT"),
			),
	}
}

// Edges of the Turn.
func (Turn) Edges() []ent.Edge {
	return nil
}
