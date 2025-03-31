# Define global variables
NVIDIA_VERSION ?= 565.57.01
MLX_VERSION ?= 24.10-2.1.8.0
WWDRACUT_VERSION ?= 4.6.0
RSTUDIO_VERSION ?= 2024.12.1-563
PODMAN_ARGS ?= 
DATE := $(shell date +\%Y\%m\%d)
TIME := $(shell date +\%H\%M)

# Repository base path (Overlays)
REPO_BASE := /var/lib/warewulf/overlays
REPO_SUFFIX := /rootfs/etc/yum.repos.d/

# Directories
INSTALL_TMP := .install.tmp
BUILD_TMP_DIR := ./.buildtmp
DRACUT_CMD := "/root/wwdracut"

# Define color codes
RED := [0;31m
GREEN := [0;32m
YELLOW := [0;33m
BLUE := [0;34m
NC := [0m # No Color

# Define the get-dependencies macro to expand variables immediately
# get-nvidia-driver parameters:
# $(1): Architecture (x86_64, aarch64)
define get-nvidia-driver
$(BUILD_TMP_DIR)/NVIDIA-Linux-$(1)-$(NVIDIA_VERSION).run
endef

# get-mlx-driver parameters:
# $(1): Architecture (x86_64, aarch64)
# $(2): OS version (8.10, 9.5, etc.)
define get-mlx-driver
mlx/MLNX_OFED_LINUX-$(MLX_VERSION)-rhel$(2)-$(1).tgz
endef

# Default target
.PHONY: all
all: solcuda phxcuda rocm vectorengine gracehopper success install

.PHONY: sol
sol: cuda rocm vectorengine gracehopper success

.PHONY: phx
phx: phxcuda

.PHONY: cuda
cuda: solcuda phxcuda gracehopper


# Initialize environment
.PHONY: init
init: packages
	@mkdir -p $(BUILD_TMP_DIR)
	@cp /etc/passwd $(BUILD_TMP_DIR)/passwd
	@cp /etc/group $(BUILD_TMP_DIR)/group
	@touch $(BUILD_TMP_DIR)/init

# Function to prepare repos for a specific target
# prepare_repos parameters:
# $(1): Repository path (repos, repos-aarch64, etc.)
define prepare_repos
	@echo "$(GREEN)Staging repos from $(BLUE)$(REPO_BASE)/$(1)$(REPO_SUFFIX)$(GREEN) overlay$(NC)"
	@mkdir -p $(BUILD_TMP_DIR)/$(1)/repos
	@cp $(REPO_BASE)/$(1)$(REPO_SUFFIX)/*.repo $(BUILD_TMP_DIR)/$(1)/repos
endef

# Download NVIDIA driver
$(BUILD_TMP_DIR)/NVIDIA-Linux-%.run:
	@echo "$(YELLOW)Downloading NVIDIA Driver $(BLUE)NVIDIA-Linux-$*$(YELLOW)...$(NC)"
	@mkdir -p $(BUILD_TMP_DIR)
	@cd $(BUILD_TMP_DIR); \
		wget https://download.nvidia.com/XFree86/Linux-$(word 1,$(subst -, ,$*))/$(NVIDIA_VERSION)/NVIDIA-Linux-$*.run; \
		cd -

# Download MLX driver
mlx/MLNX_OFED_LINUX-$(MLX_VERSION)-rhel%.tgz:
	@echo "$(YELLOW)Downloading MLX Driver $(BLUE)MLNX_OFED_LINUX-$(MLX_VERSION)-rhel$*.$(YELLOW)...$(NC)"
	@mkdir -p mlx
	@cd mlx; \
		wget https://content.mellanox.com/ofed/MLNX_OFED-$(MLX_VERSION)/MLNX_OFED_LINUX-$(MLX_VERSION)-rhel$*.tgz; \
		cd -

# Generic function for podman build
# podman_build parameters:
# $(1): Target/variant name (cuda, rocm, etc.)
# $(2): Container tag name (sol-x86_64-rocky8.10-cuda-555.42.02, etc.)
# $(3): Architecture (x86_64, aarch64)
# $(4): OS version (8.10, 9.5, etc.)
# $(5): Repository overaly name (repos, repos-aarch64, etc.)
define podman_build
	@echo "$(GREEN)Building $(BLUE)$(1)$(GREEN) variant$(NC)"
	$(call prepare_repos,$(5))
	@if [ "$(shell uname -m)" != "$(3)" ]; then \
		echo "$(YELLOW)Setting up QEMU for cross-architecture build ($(BLUE)$(3)$(YELLOW))...$(NC)"; \
		podman run --rm --privileged multiarch/qemu-user-static --reset -p yes; \
	fi
	@podman build $(PODMAN_ARGS) \
		--file ./Containerfile.$(1) \
		--build-arg NVIDIA_VERSION=$(NVIDIA_VERSION) \
		--build-arg MLX_VERSION=$(MLX_VERSION)-rhel$(4)-$(3) \
		--build-arg WWDRACUT_VERSION=$(WWDRACUT_VERSION) \
		--build-arg RSTUDIO_VERSION=$(RSTUDIO_VERSION) \
		--build-arg PS1TAG=$(2) \
		--build-arg BUILD_TMP_DIR=$(BUILD_TMP_DIR) \
		--build-arg TARGET_ARCH=$(3) \
		--build-arg OS_VERSION=$(4) \
		--build-arg REPO_PATH=$(5) \
		--volume $(PWD):/mnt:O \
		--tag $(2):$(DATE)_$(TIME) || { \
		echo "$(RED)Error: Failed to build $(BLUE)$(1)$(RED) variant with exit code $$?. Exiting.$(NC)"; \
		exit 1; \
	}
	@podman save $(2):$(DATE)_$(TIME) --output $(2).$(DATE)_$(TIME).tar || { \
		echo "$(RED)Error: Failed to save $(BLUE)$(1)$(RED) variant with exit code $$?. Exiting.$(NC)"; \
		exit 1; \
	}
	@echo 'wwctl image import --syncuser $(PWD)/$(2).$(DATE)_$(TIME).tar $(2).$(DATE)' >> $(INSTALL_TMP)
	@echo 'wwctl image exec $(2).$(DATE) $(DRACUT_CMD)' >> $(INSTALL_TMP)
endef

# Target for Sol CUDA build
solcuda:
	$(eval TARGET_ARCH := x86_64)
	$(eval OS_VERSION := 8.10)
	$(eval REPOS := repos-rocky8)
	$(eval TAG := sol-$(TARGET_ARCH)-rocky$(OS_VERSION)-cuda-$(NVIDIA_VERSION))
	$(MAKE) init Containerfile.$@ $(call get-nvidia-driver,$(TARGET_ARCH)) $(call get-mlx-driver,$(TARGET_ARCH),$(OS_VERSION))
	$(call podman_build,$@,$(TAG),$(TARGET_ARCH),$(OS_VERSION),$(REPOS))
	@$(MAKE) success

# Target for PHX CUDA build
phxcuda:
	$(eval TARGET_ARCH := x86_64)
	$(eval OS_VERSION := 8.10)
	$(eval REPOS := repos-rocky8)
	$(eval TAG := phx-$(TARGET_ARCH)-rocky$(OS_VERSION)-cuda-$(NVIDIA_VERSION))
	$(MAKE) init Containerfile.$@ $(call get-nvidia-driver,$(TARGET_ARCH))
	$(call podman_build,$@,$(TAG),$(TARGET_ARCH),$(OS_VERSION),$(REPOS))
	@$(MAKE) success

# Target for PHX legacy CUDA build, with fixed NVIDIA version
phxlegacycuda:
	$(eval TARGET_ARCH := x86_64)
	$(eval OS_VERSION := 8.10)
	$(eval REPOS := repos-rocky8)
	$(eval NVIDIA_VERSION := 515.105.01)
	$(eval TAG := phx-$(TARGET_ARCH)-rocky$(OS_VERSION)-cuda-$(NVIDIA_VERSION))
	$(MAKE) init Containerfile.$@ NVIDIA_VERSION=$(NVIDIA_VERSION) \
		$(BUILD_TMP_DIR)/NVIDIA-Linux-$(TARGET_ARCH)-$(NVIDIA_VERSION).run
	$(call podman_build,$@,$(TAG),$(TARGET_ARCH),$(OS_VERSION),$(REPOS))
	@$(MAKE) success

# Target for ROCM build
rocm:
	$(eval TARGET_ARCH := x86_64)
	$(eval OS_VERSION := 8.10)
	$(eval REPOS := repos-rocky8)
	$(eval TAG := sol-$(TARGET_ARCH)-rocky$(OS_VERSION)-$@)
	$(MAKE) init Containerfile.$@ $(call get-mlx-driver,$(TARGET_ARCH),$(OS_VERSION))
	$(call podman_build,$@,$(TAG),$(TARGET_ARCH),$(OS_VERSION),$(REPOS))
	@$(MAKE) success

# Target for GraceHopper build
gracehopper:
	$(eval TARGET_ARCH := aarch64)
	$(eval OS_VERSION := 9.5)
	$(eval REPOS := repos-aarch64)
	$(eval TAG := sol-$(TARGET_ARCH)-rocky$(OS_VERSION)-cuda-$(NVIDIA_VERSION))
	$(MAKE) init Containerfile.$@ $(call get-nvidia-driver,$(TARGET_ARCH)) $(call get-mlx-driver,$(TARGET_ARCH),$(OS_VERSION))
	$(call podman_build,$@,$(TAG),$(TARGET_ARCH),$(OS_VERSION),$(REPOS))
	@$(MAKE) success

# Target for VectorEngine FPGA build
vectorengine:
	$(eval TARGET_ARCH := x86_64)
	$(eval OS_VERSION := 8.8)
	$(eval REPOS := fpga_vectorEngine)
	$(eval TAG := sol-$(TARGET_ARCH)-rocky$(OS_VERSION)-$@)
	$(MAKE) init Containerfile.$@ $(call get-mlx-driver,$(TARGET_ARCH),$(OS_VERSION))
	$(call podman_build,$@,$(TAG),$(TARGET_ARCH),$(OS_VERSION),$(REPOS))
	@$(MAKE) success

# Template for creating a new variant
# Copy this section and replace 'newvariant' with your variant name
# Make sure the variant name has a matching Containerfile.variant_name
# Adjust TARGET_ARCH, OS_VERSION, REPOS as needed
# Add any specific dependencies if needed
#newvariant:
#	$(eval TARGET_ARCH := x86_64)
#	$(eval OS_VERSION := 8.10) # Expected 
#	$(eval REPOS := repos) # This is the name of the overlay containing the .repo files
#	$(eval TAG := sol-$(TARGET_ARCH)-rocky$(OS_VERSION)-$@)
#	$(MAKE) init Containerfile.$@ $(call get-mlx-driver,$(TARGET_ARCH),$(OS_VERSION))
#	# Add any other specific dependencies here if needed
#	# e.g., $(call get-nvidia-driver,$(TARGET_ARCH)) for NVIDIA support
#	$(call podman_build,$@,$(TAG),$(TARGET_ARCH),$(OS_VERSION),$(REPOS))
#	@$(MAKE) success
#	

# Clean up
.PHONY: clean
clean:
	@initial_space=$$(df --output=avail . | tail -n 1); \
		echo "$(YELLOW)Removing temporary build files...$(NC)"; \
		rm -rf $(BUILD_TMP_DIR) $(INSTALL_TMP) ; \
		echo "$(YELLOW)Removing old builds...$(NC)"; \
		rm -f ./*.tar; \
		final_space=$$(df --output=avail . | tail -n 1); \
		space_freed=$$((final_space - initial_space)); \
                space_freed_gb=$$(awk "BEGIN {printf \"%.2f\", $$space_freed / 1024 / 1024}"); \
                echo "$(GREEN)Free disk space: $(BLUE)$$(df -h --output=avail . | tail -n 1)$(GREEN) (cleaned: $(BLUE)$${space_freed_gb}G$(GREEN))$(NC)";

# Very clean up
.PHONY: veryclean
veryclean: clean
	@initial_space=$$(df --output=avail . | tail -n 1); \
		echo "$(YELLOW)Removing dangling podman images...$(NC)"; \
                podman image prune -f >/dev/null; \
		echo "$(YELLOW)Cleaning up and resetting podman...$(NC)"; \
		for i in $$(podman container list --external | tail -n +2 | cut -d' ' -f 1); do \
			podman container rm $$i -f; \
		done; \
		rm -rf /var/lib/containers/storage/overlay/ || true; \
		sleep 1 && podman system reset -f >/dev/null; \
		final_space=$$(df --output=avail . | tail -n 1); \
		space_freed=$$((final_space - initial_space)); \
		space_freed_gb=$$(awk "BEGIN {printf \"%.2f\", $$space_freed / 1024 / 1024}"); \
		echo "$(GREEN)Free disk space: $(BLUE)$$(df -h --output=avail . | tail -n 1)$(GREEN) (cleaned: $(BLUE)$${space_freed_gb}G$(GREEN))$(NC)";

# Display install log
.PHONY: success
success:
ifeq ($(wildcard $(INSTALL_TMP)),)
	@echo "$(RED)No images to be added to warewulf.$(NC)"
else
	@echo "$(GREEN)========================================================================$(NC)"
	@echo "$(GREEN)Success! Now run the following commands to import the images into Warewulf:$(NC)"
	@cat $(INSTALL_TMP)
	@echo "$(GREEN)You can also run 'make install' to execute the above commands.$(NC)"
	@echo "$(GREEN)========================================================================$(NC)"
endif

# Install target to run import commands
.PHONY: install
install: 
ifeq ($(wildcard $(INSTALL_TMP)),)
	@echo "$(RED)No images to be added to Warewulf.$(NC)"
else
	@echo "$(GREEN)Running import commands...$(NC)"
	@bash -c "$$(cat $(INSTALL_TMP))"
endif
