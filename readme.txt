뱀서류 게임 프로토타입 개발 문서 (v1.1 업데이트)1. 프로젝트 개요개발 엔진: Godot 4.x장르: 2D 로그라이크 불릿헬 (Vampire Survivors Like)핵심 루프: 화면 밖 몬스터 스폰 ➔ 자동 무기 시스템 및 오브젝트 풀 기반 사냥 ➔ 보석(XP) 자석 흡수 ➔ 실시간 일시정지 및 리소스 데이터 기반 랜덤 3택 레벨업 ➔ 캐릭터 및 무기 강화.2. 프로젝트 폴더 및 파일 구조 (File Structure)3대 최적화(리소스화, 풀링, 무한 맵) 및 레이어 정리를 반영한 최종 디렉토리 구조입니다.Plaintextres://
├── assets/                     # 모든 그래픽 자원(이미지)
│   ├── Blade.png, Bullet.png, Player.png, Enemy.png, Gem.png
│
├── resources/                  # [업데이트] 데이터 기반 기획 리소스 폴더
│   ├── items/                  # 업그레이드 아이템 데이터 (.tres)
│   │   ├── blade_upgrade.tres
│   │   └── bullet_upgrade.tres
│   └── item_data_resource.gd   # 아이템 데이터 정의 스크립트
│
├── core/                       # 게임 핵심 매니저 및 뼈대
│   ├── main.tscn               # 게임 전체 무대 (메인 씬)
│   ├── main.gd                 # 게임 오버, 점수 등 월드 총괄
│   ├── map_manager.gd          # [업데이트] 청크 기반 무한 타일맵 재배치 시스템
│   ├── enemy_spawner.gd        # 시간 경과에 따른 점진적 몬스터 스폰 매니저
│   └── object_pooler.gd        # [업데이트] Enemy/Bullet 성능 최적화를 위한 풀링 매니저
│
├── entities/                   # 게임 내 실체물(엔티티)
│   ├── player.tscn / .gd       # 플레이어 캐릭터 (이동, 입력, 피격, XP 트리거)
│   ├── enemy.tscn / .gd        # 몬스터 (추적 AI, 플레이어 충돌 데미지, 풀 복귀 및 보석 드롭)
│   ├── bullet.tscn / .gd       # [수정] 투사체 (물리 버그 방지 즉시 차단 로직 포함)
│   ├── blade_manager.tscn/.gd  # 공전하는 칼날 무기 매니저 (자식 Area2D 제어)
│   └── gem.tscn / .gd          # [수정] 경험치 보석 (자석 효과 및 물리 버그 방지 즉시 차단 로직 포함)
│
└── ui/
    ├── game_ui.tscn / .gd      # HUD, .tres 리소스 기반 랜덤 3택 레벨업 시스템
3. 시스템 아키텍처 및 노드 관계도Plaintext[Main Scene]
 ├── MapManager (Node2D) ➔ 플레이어 좌표를 감시하며 타일맵 청크를 무한히 재배치
 ├── ObjectPooler (Node) ➔ Enemy / Bullet 노드를 queue_free 대신 active/inactive 상태로 풀링 관리
 ├── EnemySpawner (Node2D) ➔ 플레이어 시야 밖 750px 반지름 원형 좌표에 몹 생성 요청 (Pooler 연동)
 ├── Player (CharacterBody2D)
 │    ├── WeaponTimer (Timer) ➔ 최단 거리 적 타겟팅 발사 요청
 │    ├── DetectionArea (Area2D) ➔ 적 감지 레이더
 │    └── BladeManager (Node2D) ➔ 회전 칼날 제어
 └── GameUI (CanvasLayer) ➔ Process Mode = ALWAYS (일시정지 중 리소스 데이터 카드 선택 가능)
4. 핵심 기능 및 트러블슈팅 구현 사항① [크리티컬 버그 해결] 물리 연산 프레임 지연으로 인한 플레이어 순간이동 버그 차단원인 분석: 몬스터가 죽거나 보석이 닿는 순간 데미지 정산/레벨업 등으로 일시정지 연산이 물리 프레임 사이에 끼어들면, 고도 엔진의 $CollisionShape2D.set_deferred("disabled", true)가 적용되기 전까지 찰나의 순간(1~2프레임) 동안 충돌체가 물리 세계에 겹친 상태로 남아있게 됨. 이로 인해 CharacterBody2D인 플레이어를 밀어내며 사방으로 튕기는(순간이동) 버그 발생.해결 매커니즘: 데미지 처리 및 획득 함수(_absorb_gem, take_damage)가 호출되는 즉시, 지연 처리(deferred)를 기다리지 않고 물리 레이어와 마스크를 즉시 0으로 강제 초기화.💡 핵심 트러블슈팅 코드 패턴GDScript# 충돌 즉시 해당 오브젝트를 물리 세계에서 유령(없는 존재)으로 만듦
collision_layer = 0
collision_mask = 0
$CollisionShape2D.set_deferred("disabled", true) # 안전을 위한 2중 잠금
결과: 일시정지가 되거나 몬스터가 죽는 순간 연산이 밀려도 플레이어를 물리적으로 전혀 밀어내지 못하므로 순간이동 버그를 100% 완벽히 차단함.② [최적화 완료] 오브젝트 풀링 (Object Pooling)수백 마리의 몬스터와 투사체가 빈번하게 생성/삭제되며 발생하는 메모리 파편화 및 CPU 병목을 방지하기 위해 queue_free() 대신 활성화/비활성화 방식을 사용.몬스터 사망 또는 총알 충돌 시 풀(ObjectPooler)로 반환되어 visible = false 및 물리 레이어 0 상태로 대기 후 스폰 시 재사용.③ [최적화 완료] 무한 배경 타일맵 (Infinite Tilemap)플레이어 중심의 $3 \times 3$ 청크(Chunk) 배열을 구성하여, 플레이어가 한 방향으로 이동할 때 시야에서 멀어진 반대편 청크를 이동 방향 앞쪽으로 순간이동 재배치하는 알고리즘 구현. 무한히 움직여도 메모리 누수 없이 배경 유지.④ [구조 최적화] 리소스(.tres) 기반 중앙 집중 데이터 관리기존 하드코딩된 item_db 딕셔너리를 Godot의 내장 데이터 가방인 Resource 파일로 분리. 기획 데이터(아이템 아이콘, 이름, 설명, 레벨별 스탯 스케일링)를 인스펙터 창에서 코딩 없이 수정할 수 있도록 결합도 낮춤.

5. 최종 물리 레이어 매트릭스 설정 (Layer & Mask)순간이동 버그 재발 방지 및 원활한 충돌 연산을 위해 정리한 물리 매트릭스 설계입니다.레이어 번호레이어 이름설정 대상충돌 마스크 (Mask) 설정 및 이유
Layer 1Player플레이어 Mask 설정안함 (코드 자체에서 몬스터와 충돌하여 피격당하고, 보석을 자석으로 끌어당김)
Layer 2Enemy몬스터Mask 1 (플레이어를 벽처럼 인지하고 추적하기 위함)
Layer 3Gem경험치 보석Mask 0 (코드 자체에서 플레이어만 감지하여 자석 및 흡수 연산 시작)
Layer 4Bullet플레이어 총알Mask 2 (오직 몬스터만 맞춰서 body_entered를 터트림)
