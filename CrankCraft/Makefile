REPO_ROOT := $(shell git rev-parse --show-toplevel)
PRODUCT := CrankCraft.pdx
SRC += $(REPO_ROOT)/Sources/CPlaydate/playdate.c
include $(REPO_ROOT)/CrankCraft/swift.mk

# MARK: - Playdate Swift Sources Collection (Dynamic)
# Автоматически находим все файлы, но контролируем порядок через приоритеты

define collect_swift_sources
	$(shell find $(REPO_ROOT)/Sources/Playdate/$(1) -name "*.swift" -type f 2>/dev/null | sort)
endef

# Определяем порядок компиляции модулей (от базовых к зависимым)
PLAYDATE_MODULE_ORDER := \
	Extensions \
	Graphics/Types \
	Graphics/Utils \
	Graphics/Resources \
	Graphics/Rendering \
	System/Types \
	System/Utils \
	System/Resources \
	Sprites/Types \
	Sprites/Utils \
	Sprites/Resources \
	Graphics \
	System \
	Sprites \

# Собираем файлы в правильном порядке
PLAYDATE_SWIFT_SOURCES := \
	$(foreach module,$(PLAYDATE_MODULE_ORDER),$(call collect_swift_sources,$(module))) \
	$(wildcard $(REPO_ROOT)/Sources/Playdate/*.swift)

# Удаляем дубликаты и пустые строки
PLAYDATE_SWIFT_SOURCES := $(sort $(filter %.swift,$(PLAYDATE_SWIFT_SOURCES)))

$(info [Playdate Build] Compiling $(words $(PLAYDATE_SWIFT_SOURCES)) Swift files)
$(info [Playdate Build] Module order: $(PLAYDATE_MODULE_ORDER))

# Остальное без изменений...
build/Modules/playdate_device.o: $(PLAYDATE_SWIFT_SOURCES)
	@echo "→ Compiling Playdate module for device ($(words $^) files)..."
	@mkdir -p build/Modules
	$(SWIFT_EXEC) $(SWIFT_FLAGS) $(SWIFT_FLAGS_DEVICE) -c $^ -emit-module -o $@

build/Modules/playdate_simulator.o: $(PLAYDATE_SWIFT_SOURCES)
	@echo "→ Compiling Playdate module for simulator ($(words $^) files)..."
	@mkdir -p build/Modules
	$(SWIFT_EXEC) $(SWIFT_FLAGS) $(SWIFT_FLAGS_SIMULATOR) -c $^ -emit-module -o $@

# MARK: - Build Playdate Overlay Swift Module
build/Modules/playdate_device.o: $(REPO_ROOT)/Sources/Playdate/*.swift
	$(SWIFT_EXEC) $(SWIFT_FLAGS) $(SWIFT_FLAGS_DEVICE) -c $^ -emit-module -o $@

build/Modules/playdate_simulator.o: $(REPO_ROOT)/Sources/Playdate/*.swift
	$(SWIFT_EXEC) $(SWIFT_FLAGS) $(SWIFT_FLAGS_SIMULATOR) -c $^ -emit-module -o $@

# MARK: - Build Game Swift Object
build/game_device.o: Sources/*.swift | build/Modules/playdate_device.o
	$(SWIFT_EXEC) $(SWIFT_FLAGS) $(SWIFT_FLAGS_DEVICE) -c $^ -o $@
$(OBJDIR)/pdex.elf: build/game_device.o
OBJS += build/game_device.o

build/game_simulator.o: Sources/*.swift | build/Modules/playdate_simulator.o
	$(SWIFT_EXEC) $(SWIFT_FLAGS) $(SWIFT_FLAGS_SIMULATOR) -c $^ -o $@
$(OBJDIR)/pdex.${DYLIB_EXT}: build/game_simulator.o
SIMCOMPILER += build/game_simulator.o

# MARK: - Cleanup
.PHONY: clean-swift
clean-swift:
	@echo "→ Cleaning Swift build artifacts..."
	@rm -rf build/Modules
	@rm -f build/game_*.o
	@rm -rf build/module-cache

# MARK: - Debug
.PHONY: show-sources
show-sources:
	@echo "=== Extensions ==="
	@echo "$(call collect_swift_sources,Extensions)"
	@echo ""
	@echo "=== All Sources (in order) ==="
	@echo "$(PLAYDATE_SWIFT_SOURCES)" | tr ' ' '\n'
