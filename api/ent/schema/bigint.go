package schema

import (
	"database/sql"
	"database/sql/driver"
	"fmt"
	"io"
	"math/big"
	"strconv"
	"strings"

	"entgo.io/ent/dialect"
)

var BigIntSchemaType = map[string]string{
	dialect.Postgres: "numeric",
}

type BigInt struct {
	*big.Int
}

func NewBigInt(i int64) BigInt {
	return BigInt{Int: big.NewInt(i)}
}

func (b *BigInt) Scan(src interface{}) error {
	var i sql.NullString
	if err := i.Scan(src); err != nil {
		return err
	}
	if !i.Valid {
		return nil
	}
	if b.Int == nil {
		b.Int = big.NewInt(0)
	}
	// Value came in a floating point format.
	if strings.ContainsAny(i.String, ".+e") {
		f := big.NewFloat(0)
		if _, err := fmt.Sscan(i.String, f); err != nil {
			return err
		}
		b.Int, _ = f.Int(b.Int)
	} else if _, err := fmt.Sscan(i.String, b.Int); err != nil {
		return err
	}
	return nil
}

func (b BigInt) Value() (driver.Value, error) {
	if b.Int == nil {
		return "", nil
	}
	return b.String(), nil
}

func (b BigInt) Add(c BigInt) BigInt {
	b.Int = b.Int.Add(b.Int, c.Int)
	return b
}

func (b BigInt) MarshalJSON() ([]byte, error) {
	return []byte(fmt.Sprintf(`"%s"`, b.String())), nil
}

func (b *BigInt) UnmarshalJSON(p []byte) error {
	if string(p) == "null" {
		return nil
	}

	b.Int = new(big.Int)

	// BigInts are represented as strings in JSON. We
	// remove the enclosing quotes to provide a plain
	// string number to SetString.
	s := string(p[1 : len(p)-1])
	if i, _ := b.Int.SetString(s, 10); i == nil {
		return fmt.Errorf("unmarshalling big int: %s", string(p))
	}

	return nil
}

func (b BigInt) MarshalGQL(w io.Writer) {
	fmt.Fprint(w, strconv.Quote(b.String()))
}

func (b *BigInt) UnmarshalGQL(v interface{}) error {
	if bi, ok := v.(string); ok {
		b.Int = new(big.Int)
		b.Int, ok = b.Int.SetString(bi, 10)
		if !ok {
			return fmt.Errorf("invalid big number: %s", bi)
		}
	}

	return fmt.Errorf("invalid big number")
}
