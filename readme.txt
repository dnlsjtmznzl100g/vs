뱀서류 게임 프로토타입 개발 문서 (v1.2)
1. 프로젝트 개요

개발 엔진: Godot 4.x

장르: 2D 로그라이크 불릿헬 (Vampire Survivors Like)

핵심 루프:

몬스터 스폰 링 생성 → EnemyManager 등록 → 자동 무기 시스템 및 오브젝트 풀 기반 사냥 → 보석(XP) 획득 → 랜덤 3택 레벨업 → 캐릭터 및 무기 강화 → 진화(Evolution)

2. 최근 아키텍처 변경 사항
완료
EnemyManager 도입
Spawn Ring 기반 적 탐색 시스템
DetectionArea 의존도 감소
ItemDataResource 기반 데이터 구조 전환 시작
진행 중
Item DB → Resource DB 완전 이관
Evolution Resource 시스템 구축
보류
Gem Merge
Save / Load
Stage Director
3. EnemyManager 시스템
기존 구조

Player
└ DetectionArea
└ get_overlapping_bodies()

문제점

플레이어가 모든 적을 감시
Area2D 충돌 계산 발생
적 수 증가 시 성능 저하
신규 구조

EnemyManager
├ active_enemies
└ nearest_enemy()

Player
└ EnemyManager에게 최근접 적 질의

장점

Area2D 제거 가능
적 탐색 중앙화
향후 공간 분할 적용 가능
Enemy 등록

enemy.gd

func reset_enemy():
EnemyManager.register_enemy(self)

Enemy 해제

enemy.gd

func die():
EnemyManager.unregister_enemy(self)

Player 타겟 탐색

player.gd

func _on_weapon_timer_timeout():
var target = EnemyManager.get_nearest_enemy(global_position)

if target:
    shoot_at(target.global_position)
4. Spawn Ring 시스템
목적

플레이어 주변에만 적을 생성하여

탐색 범위 제한
성능 최적화
무한맵 대응
구조

Player
└ Spawn Ring
반경 1200px

적 생성 위치

1200px ~ 1400px

적 제거 거리

2000px 이상

효과

기존

전체 적 탐색

↓

변경

Spawn Ring 내부 적만 관리

5. DetectionArea 제거 준비
기존

Player
└ DetectionArea

근접 적 탐색

신규

EnemyManager

func get_nearest_enemy(position)

사용

기대 효과
Area2D 제거
Physics 연산 감소
적 1000마리 이상 대응 기반 확보
6. ItemDataResource 시스템
목적

기존 하드코딩 Dictionary 제거

Resource 정의

item_data_resource.gd

extends Resource
class_name ItemDataResource

@export var item_id: String
@export var display_name: String
@export var item_type: String
@export var effect_type: String
@export var max_level: int = 5
@export var descriptions: Array[String]

Resource 예시

blade.tres

item_id = "blade"
display_name = "궤도 칼날"
item_type = "weapon"
effect_type = "blade"

GameUI 등록

@export var item_resources: Array[ItemDataResource]

Inspector

Item Resources
├ blade.tres
├ gun.tres
├ hp.tres
└ speed.tres

Runtime DB 생성

func _ready():

for item in item_resources:
    item_db[item.item_id] = item
향후 제거 예정

var item_db = {
...
}

7. Evolution Resource 시스템 (설계 단계)
목적

하드코딩 제거

현재

if blade == 5 and hp == 5:
trigger_evolution()

목표

evolution_blade.tres

required_items

blade Lv5
passive_hp Lv5

result

blood_blade
최종 구조

resources

├ items
│ ├ blade.tres
│ ├ gun.tres
│ └ ...
│
└ evolutions
├ blood_blade.tres
└ ...

8. 오브젝트 풀링
Enemy Pool

기본

300

자동 확장 가능

Bullet Pool

기본

200

자동 확장 가능

반납 규칙

return_enemy()

return_bullet()

수행 시

collision_layer = 0
collision_mask = 0

process_mode = DISABLED

global_position = (-99999,-99999)

9. 남은 핵심 작업 우선순위
S급 (다음 작업)
ItemResource 완전 전환
Evolution Resource 구현
EnemyManager 최적화 마무리
A급
Gem Merge
Stage Director
Elite Enemy
B급
Save / Load
Achievement
Statistics
현재 프로젝트 상태

아키텍처 안정성 : 85%

데이터 주도 설계 : 60%

최적화 인프라 : 80%

콘텐츠 확장성 : 50%

전체 진행률 : 약 70%
