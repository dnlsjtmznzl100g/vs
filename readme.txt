뱀서류 게임 프로토타입 개발 문서 (Development Document)
1. 프로젝트 개요
• 개발 엔진: Godot 4
• 장르: 2D 로그라이크 불릿헬 (Vampire Survivors Like)
• 핵심 루프: 화면 밖 몬스터 스폰 ➔ 자동 무기 시스템으로 사냥 ➔ 보석(XP) 획득 ➔ 실시간 일시정지 및 데이터 기반 랜덤 3택 레벨업 ➔ 캐릭터 및 무기 강화.


2. 프로젝트 폴더 및 파일 구조 (File Structure)
현재 프로젝트의 루트(res://) 구조와 각 파일의 핵심 역할이야.
Plaintext
res://
├── assets/                 # 모든 그래픽 자원(이미지) 관리 폴더
│   ├── Blade.png           # 회전 칼날 이미지
│   ├── Bullet.png          # 총알 투사체 이미지
│   ├── Player.png          # 플레이어 캐릭터 이미지
│   ├── Enemy.png           # 몬스터 이미지
│   └── Gem.png             # 경험치 보석 이미지
│
├── main.tscn               # 게임의 전체 무대 (메인 씬)
├── enemy_spawner.gd        # 시간 경과에 따른 점진적 몬스터 스폰 매니저
│
├── player.tscn             # 플레이어 캐릭터 씬
├── player.gd               # 이동, 입력, 피격 처리, 경험치 및 레벨업 트리거
│
├── blade_manager.tscn      # 공전하는 칼날 무기 씬
├── blade_manager.gd        # 칼날 회전 속도 제어 및 자식 Area2D 충돌/데미지 총괄
│
├── bullet.tscn             # 발사체(투사체) 씬 (Area2D)
├── bullet.gd               # 지정된 적 방향 직진 이동 및 충돌 시 단발 데미지
│
├── enemy.tscn              # 기본 몬스터 씬 (CharacterBody2D)
├── enemy.gd                # 플레이어 추적 AI, 플레이어 충돌 시 데미지, 사망 시 보석 드롭
│
├── gem.tscn                # 경험치 보석 씬 (Area2D)
├── gem.gd                  # 바닥 대기 및 플레이어 접근 시 자석 효과 흡수
│
├── game_ui.tscn            # 인게임 HUD 및 메뉴 CanvasLayer 씬
└── game_ui.gd              # HP/XP 바 갱신, 데이터 기반 랜덤 3택 레벨업 시스템, 게임 종료 처리


3. 시스템 아키텍처 및 노드 관계도
각 오브젝트가 고도 엔진 내부에서 어떻게 상호작용하는지 정리한 구조야.
Plaintext
[Main Scene]
 ├── Player (CharacterBody2D)
 │    ├── WeaponTimer (Timer) ➔ 일정 주기마다 감지 영역 내 가장 가까운 적에게 총알 발사
 │    ├── DetectionArea (Area2D) ➔ 적 감지 레이더 (반지름 설정)
 │    └── BladeManager (Node2D) [레벨업 시 부착] ➔ 플레이어 중심으로 자식 칼날(Area2D)들을 공전시킴
 │
 ├── EnemySpawner (Node2D) ➔ 시간(elapsed_time) 비례 스폰량 증가, 플레이어 시야 밖 원형 좌표 스폰
 ├── [Enemies / Bullets / Gems] ➔ 독립적 이동을 위해 최상위 Main Scene의 자식으로 동적 생성(Spawn)
 └── GameUI (CanvasLayer) ➔ Process Mode = ALWAYS 설정으로 일시정지(Paused) 중에도 카드 선택 가능



4. 핵심 기능 구현 사항
① 데이터 기반 랜덤 3택 레벨업 (Data-Driven Level Up)
• 특징:item_db 딕셔너리로 아이템 데이터를 중앙 집중 관리. 새 무기/패시브 추가 시 코드 수정 최소화.
• 시퀀스: 레벨업 트리거 ➔ 만렙 제외 필터링 ➔ shuffle()을 통한 랜덤 3택 ➔ 게임 일시정지(get_tree().paused = true) 및 선택지 노출 ➔ 동적 시그널 바인딩(.bind(item_id))으로 보상 지급 ➔ 일시정지 해제.
• 확장성: 칼날 레벨 5 + 체력 레벨 5 달성 시 발동하는 조합(진화) 시스템의 기반 마련.
② 화면 밖 스폰 메커니즘 (Out-of-Screen Spawning)
• 삼각함수($\cos, \sin$)를 활용해 플레이어의 global_position 기준 반지름 750px 둘레의 무작위 좌표에 몬스터 생성.
• 플레이어 이동 방향과 관계없이 항상 화면 자연스러운 경계 밖에서 적이 습격하도록 유도.
③ 자동 타겟팅 및 무기 컴포넌트
• 자동 권총:DetectionArea 내 get_overlapping_bodies() 중 최단 거리의 enemy 그룹 노드를 연산하여 투사체 방향(direction) 지정 발사.
• 공전 칼날: 상위 매니저의 _process 내 rotation += speed * delta 연산 하나로 하위 모든 칼날 자식들의 공전 궤도를 제어. 자식 노드들의 충돌 신호를 _ready에서 루프로 자동 수집하여 일괄 데미지 처리.


5. 다음 단계 개발 로드맵 (Next Action)
이 프로토타입을 정식 게임 퀄리티로 올리기 위해 고려해볼 수 있는 다음 스텝들이야.
1. 무기 확장 및 리소스화:item_db 구조를 고도의 자산 시스템인 .tres (Resource) 파일로 분리하여 기획 데이터와 코드를 분리하기.
2. 무한 배경 타일맵(Infinite Tilemap): 플레이어가 사방으로 이동해도 배경이 끊기지 않도록 플레이어 좌표 중심의 청크(Chunk) 기반 타일맵 재배치 시스템 구현.
3. 오브젝트 풀링(Object Pooling): 화면에 몬스터나 총알이 수백~수천 개씩 뜰 때 발생하는 성능 저하(렉)를 방지하기 위해 노드를 queue_free() 대신 재사용하는 풀링 시스템 도입.
