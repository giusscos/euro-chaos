class_name DeliveryResult
extends RefCounted
## How one delivery went.

enum Outcome { DELIVERED, LATE, RUINED, ABANDONED }

var mission: MissionData
var outcome: Outcome = Outcome.DELIVERED
## Seconds from pickup to delivery.
var time_taken: float = 0.0
var time_limit: float = 0.0
## Cargo condition at the end, 0..1.
var condition: float = 1.0
var payout: int = 0
var tip: int = 0
## 0..5
var stars: int = 0


func total() -> int:
	return payout + tip


func is_success() -> bool:
	return outcome == Outcome.DELIVERED or outcome == Outcome.LATE
