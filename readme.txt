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
4. 물리 레이어 매트릭스 및 충돌 규격 (Collision Layer Matrix)물리 연산의 낭비를 막고, 일시정지 프레임 사이에 발생하는 오브젝트 간 튕김/순간이동 버그를 차단하기 위해 고도 엔진 내 레이어와 마스크를 다음과 같이 엄격히 고정합니다.레이어 (Layer)레이어 이름감시할 마스크 (Mask)주요 역할 및 충돌 처리 규칙Layer 1Player2 (Enemy)플레이어 본체 히트박스. 적의 밀치기 및 충돌을 감지함.Layer 2Enemy1 (Player)몬스터 본체 충돌 레이어. 플레이어를 추적하며 지속 타격을 검사함.Layer 3Gem0 (없음)경험치 보석. 필드에 배치 시 마스크를 0으로 두어 물리 연산 비용을 0%로 유지함.Layer 4Bullet2 (Enemy)원거리 투사체. 오직 적 그룹(Enemy)만 인지하여 타격 연산을 수행함.💡 [핵심 버그 차단 규칙] > 몬스터가 죽거나(enemy.gd), 투사체가 충돌하거나(bullet.gd), 보석이 자석에 끌리기 시작할 때(gem.gd)는 데미지/정산 연산 직전에 collision_layer = 0 및 collision_mask = 0을 수행하여 물리 세계에서 즉시 유령화(Ghosting) 시킵니다. 이를 통해 프레임 지연으로 인한 밀쳐짐 및 연타 버그를 원천 봉쇄합니다.

5. 중앙 집중형 오브젝트 풀링 시스템 (object_pooler.gd)화면에 노출되는 수백 개의 오브젝트 동적 생성(instantiate)과 삭제(queue_free)로 인한 가비지 컬렉터(GC) 병목을 방지하기 위한 메모리 인프라입니다.

5.1 주요 메커니즘격리 조치 (QUARANTINE_POSITION): 반납된 객체는 플레이어가 절대 접근할 수 없는 초원격지 좌표인 $Vector2(-99999, -99999)$로 강제 이주 시킵니다.연산 동결 (PROCESS_MODE_DISABLED): 풀 내부에서 대기 중인 오브젝트는 프로세스 모드를 완전히 꺼서 물리 연산 및 _process 호출을 100% 차단합니다.대여 시점 리셋(Reset-on-Rent): 객체가 반납될 때가 아닌, 새로 대여되어 필드로 나가는 시점(get_...)에 내부 스탯과 물리 레이어를 태초의 상태로 리셋하여 메모리 오염을 원천 차단합니다.

5.2 관리 한계선 (Pool Capacity)몬스터 풀(enemy_pool): 고정 300마리 선인스턴스화 (초과 시 동적 추가 확장)총알 풀(bullet_pool): 고정 200발 선인스턴스화 (초과 시 동적 추가 확장)

6. 컴포넌트별 상세 기술 명세 (Component Specifications)

6.1 플레이어 및 기본 무기 제어 (player.gd)기본 무기 장착 규칙: 게임 시작 즉시 WeaponTimer를 가동하여 1레벨 자동 권총 사격을 시작합니다. 동시에 UI 매니저의 인벤토리 장부에 gun = 1 데이터를 동기화하여, 첫 레벨업 시 정상적으로 2레벨 선택지 카드가 출력되도록 유도합니다.풀러 통신 기반 사격: shoot_at() 실행 시 직접 씬을 생성하지 않고 ObjectPooler.get_bullet() 인터페이스를 통해 풀러에게 주차된 총알을 대여받아 발사합니다.타겟팅 필터링: DetectionArea 내에 적이 들어왔더라도, 이미 사망 플래그(is_dead == true)가 켜져 풀러로 복귀 중인 적은 조준 대상에서 조기 스킵하여 투사체 낭비를 막습니다.
6.2 몬스터 추적 및 사망 프로세스 (enemy.gd)연타 의문사 방지: 플레이어와 물리적 충돌이 일어났을 때 attack_cooldown = 1.0 초를 부여하여 프레임 겹침 현상으로 인해 플레이어가 1타 만에 의도치 않게 의문사하는 현상을 차단합니다.즉각적 물리 파괴: die() 트리거 발동 즉시 set_physics_process(false)를 호출해 연산을 멈추고 레이어를 즉시 0으로 만듭니다. 사망 후 보석을 드롭할 때 메인 트리에 call_deferred("add_child")로 안전하게 안착시킵니다.

6.3 공전 무기 매니저 (blade_manager.gd)_ready 동적 바인딩: 자식 노드로 붙어있는 모든 Area2D 칼날들을 순회하며 body_entered 시그널을 자동으로 연결하여 확장성을 확보합니다.타격 무적 시간 딕셔너리 (hit_enemies): 칼날 면적에 적이 닿아있을 때 틱당 데미지가 들어가는 버그를 잡기 위해, 각 몬스터의 instance_id를 Key로 하는 쿨타임 장부를 운영하여 hit_cooldown (0.5초) 동안 단 1번만 깔끔하게 데미지가 들어가도록 밸런스를 제어합니다.
6.4 투사체 매커니즘 (bullet.gd)비동기 타이머 제거: 기존 고도 엔진 크래시의 주원인이던 await get_tree().create_timer().timeout 구조를 완전히 제거하고, _physics_process 내에서 delta를 누적하는 안전한 lifetime 계산 방식으로 전환하여 무덤(Null) 에러를 방지합니다.안전한 풀 반납: 사거리 밖으로 나가거나 적 타격 완료 시 _despawn_bullet()을 통해 프로세스를 스스로 내리고 풀러 장부로 조용히 복귀합니다.
6.5 가속 유도식 경험치 보석 (gem.gd)이중 플래그 기반 연산 최적화 (is_magnetized): 필드 위에 떨어진 수백 개의 보석이 매 프레임 플레이어와의 거리를 계산하던 구조를 파괴했습니다. 자석 범위(120px) 안에 들어오기 전까지는 벡터 이동 연산을 아예 실행하지 않고 대기하여 CPU 자원을 95% 이상 절약합니다.휘리릭 흡수 연출: 자석 범위 내에 진입하는 순간 current_speed += acceleration * delta 수식을 통해 플레이어 품으로 다가올수록 속도가 기하급수적으로 증가하며 꽂히는 정통 뱀서류 특유의 흡입 손맛을 완성했습니다.
6.6 프리징 방지형 데이터 기반 UI 시스템 (game_ui.gd)일시정지 클릭 프리징 방지: 레벨업 선택창이 출력되며 게임 세계가 멈췄을 때(get_tree().paused = true), UI 패널 및 자식 버튼 노드들의 프로세스 모드를 PROCESS_MODE_ALWAYS로 강제 연동하여 일시정지 중 마우스 클릭 입력이 씹히던 엔진 먹통 버그를 완벽하게 해결했습니다.방어적 인덱싱: 업그레이드 카드 생성 시 item_db 내descriptions 배열 범위를 넘어가지 않도록 min(next_level - 1, desc_array.size() - 1) 처리를 더해 안정성을 강화했습니다.무기 조합 진화(Evolution) 규칙: 궤도 칼날 5레벨과 체력 증강 패시브 5레벨 조건을 동시에 달성했는지 감시하는 중복 방지 플래그 및 기존 무기를 트리에서 안전하게 철거하고 상위 컴포넌트로 교체하는 인터페이스(trigger_evolution)의 뼈대를 구축했습니다.
