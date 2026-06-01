뱀서류 게임 프로토타입 개발 문서 (v1.2)
작업 일자

2026-06-01

오늘 완료된 작업
1. EnemyManager 도입 완료
기존 구조
Player
 └ DetectionArea
     └ get_overlapping_bodies()
         └ 가장 가까운 적 탐색

문제점

공격할 때마다 DetectionArea 내부 적 전체 순회
적 수 증가 시 비용 증가
Player가 Enemy 탐색 책임을 가짐
변경 구조
EnemyManager
 ├ active_enemies
 ├ register_enemy()
 ├ unregister_enemy()
 └ get_nearest_enemy()

Player
 └ EnemyManager에 질의

장점

적 탐색 책임 분리
DetectionArea 의존도 감소
향후 Spatial Partition 적용 가능
2. Spawn Ring 적용
기존 구조

EnemySpawner

랜덤 반지름
랜덤 각도

문제점

플레이어 근처 스폰 가능
화면 안 생성 가능성 존재
변경 구조
고정 Spawn Ring
플레이어
   ○
 ○   ○
○     ○
 ○   ○
   ○

특징

항상 화면 밖 생성
스폰 거리 일정
난이도 예측 가능
3. DetectionArea 의존도 감소
기존
var targets =
	$DetectionArea.get_overlapping_bodies()
변경
EnemyManager.get_nearest_enemy(
	global_position
)

효과

물리엔진 의존 감소
탐색 로직 단순화
4. ItemDataResource 도입
기존

game_ui.gd 내부

var item_db = {
	...
}

하드코딩

변경
resources/items/
 ├ blade.tres
 ├ gun.tres
 ├ hp.tres
 └ speed.tres
ItemDataResource
extends Resource
class_name ItemDataResource

@export var item_id: String
@export var display_name: String
@export var item_type: String
@export var effect_resource: Resource
@export var max_level: int = 5
@export var descriptions: Array[String]
5. item_db 일반화
기존
var item_db = {
	...
}
변경
var item_db = {}

for item in item_resources:
	item_db[item.item_id] = item

효과

신규 아이템 추가 시 코드 수정 불필요
.tres 등록만으로 확장 가능
6. UpgradeEffectResource 시스템 도입
신규 베이스 클래스
extends Resource
class_name UpgradeEffectResource

func apply(player, ui, level):
	pass
구현 완료
HPUpgradeEffect
GunRateUpgradeEffect
SpeedUpgradeEffect
기존 구조
match effect_type:
	"hp":
	...
	"speed":
	...
	"gun":
	...
변경 구조
item_info.effect_resource.apply(
	player_ref,
	self,
	current_lvl
)

효과

match 제거
Open/Closed Principle 적용
신규 업그레이드 추가 시 UI 수정 불필요
7. Blade 업그레이드 Resource화 진행
목표
BladeUpgradeEffect

도입

현재 상태

구현 완료

BladeUpgradeEffect.apply()

존재

발견된 문제

레벨업 카드 선택 후

effect_resource = null

출력

원인

현재 Main 씬에 등록된 item_resources가

res://main.tscn::Resource_xxxxx

형태의 내부 Resource를 참조 중

예상 구조

res://resources/items/blade.tres

가 아님

다음 작업

Main Scene

GameUI
 └ item_resources

재점검

현재 아키텍처 상태
Player
  ↓
EnemyManager
  ↓
Enemy

Level Up
  ↓
ItemDataResource
  ↓
effect_resource
  ↓
apply()
다음 우선순위
1순위

BladeUpgradeEffect 연결 문제 해결

확인 항목

blade.tres
 └ effect_resource
     └ blade_effect.tres
2순위

EvolutionResource 도입

현재

var evolution_db = {}

하드코딩 제거

3순위

EnemyDataResource

slime.tres
bat.tres
ghost.tres

적 데이터 리소스화

4순위

Gem Merge

대량 보석 생성 시 최적화 적용

권장 시점

동시 보석 500~1000개 이상
현재 프로젝트 성숙도
완료
Object Pooling
EnemyManager
Spawn Ring
ItemDataResource
UpgradeEffectResource
DetectionArea 의존도 감소
진행 중
BladeUpgradeEffect 연결
예정
EvolutionResource
EnemyDataResource
Gem Merge
무기 진화 완전 데이터화
