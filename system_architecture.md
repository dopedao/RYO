# Architecture model

The game is formed by a system of contracts in a design, here called
['aggregated architecture'](https://perama-v.github.io/cairo/game/aggregated-architecture)

The essence is to have:

- An authority (controlled ideally by community members)
- A mapping of modules
- Modules

The modules have two main types, those that a user might
interact with, and those that maintain game state variables.
Each module is backward compatible and may be upgraded as needed.
Additional modules may be added. This is achieved by the authority
updating the deployment addresses stored in the module mappings.

Imagine a network of partially connected modules. Each module may
read different game variables from the system (e.g., player stats,
item quantities, location statistics, other games states). Modules,
after being vetted, may also update some variables selectively.

## Progressive roll out

The system will initially consist of the simplest module set.
Players will interact with a contract that then utilises the other
modules for game operation. Then, additional modules can be connected.
A player may then play by interacting in two separate transactions
asynchronously. The game variables may be shared, allowing for
complex interplay.


## Deployment sequence

1. Deploy a new application contract
2. Point the application to read variables from modules, by
    1. Querying the `ModuleController` for the deployment address
    of the `module_id` of interest.
    2. Reading the state from that address.
3. If write access is desired, the process is:
    1. Community review of deployed application code
    2. `approve_module_to_module_write_access()` executed by
    the Arbiter contract, which updates permissions in the `ModuleController`.


## Interoperability requirements

Module requirements:

- All modules that maintain state that is intended for open-ended use
must point to the `ModuleController` for write-access permissions.
    - `has_write_access()` is called by the variable contract to ensure
    that the calling contract has the power to authorize updates that
    may affect other modules (which share the same variables).
- A module updgrade MUST NOT remove functions. New functions MAY
be added, but backward compatibility with other modules is required.


Example module upgrade:

- Weapon overhaul: A module contains a record of who owns which weapon.
A new module is written that keeps a record of how often
a weapon is used. It adds a new function that exposes how worn out
each weapon is. Another module may use this new variable.
- Drug upgrade: A module contains the record of who owns which
drug. A new module is written that represents the drugs as a deposited
token with limited scopes. The drugs may be deposited and made available for gameplay,
or used in another module (E.g,. Where they may be consumed permanently).
- Bug fixes: Modules can be upgraded for the purpose of redesigning
mechanisms or parameters for better play.

## Permissions flow for writing to a global state variable.

A contract that wants to write to a state variable must:

1. Off-chain determine the appropriate `module_id` for the variable.
2. Fetch the `controller_address` from internal storage.
3. Call `get_module_address()` in the `ModuleController`.
4. Call the module with the appropriate function (e.g., `update_var_x()`).
5. The module receives the request and reads the calling address with
`get_caller_address()` from the common library.
6. The module fetches the `controller_address` from internal storage.
7. The module calls the `has_write_access()` function in the `ModuleController`,
passing the caller's address (reverts if disallowed.)
8. The module then updates internal storage with the requested value.

Thus, every module has an `only_approved()` internal method that performs
steps 5-7.