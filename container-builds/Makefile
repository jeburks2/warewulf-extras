# Define variables
NVIDIA_VERSION ?= 555.42.02
MLX_VERSION ?= 23.10-3.2.2.0
PODMAN_ARGS ?= 
DATE := $(shell date +\%Y\%m\%d_\%H\%M)
REPOS := /var/lib/warewulf/overlays/repos/rootfs/etc/yum.repos.d/
ARM_REPOS := /var/lib/warewulf/overlays/repos-aarch64/rootfs/etc/yum.repos.d/
VECTOR_REPOS := /var/lib/warewulf/overlays/fpga_vectorEngine/rootfs/etc/yum.repos.d/
INSTALL_TMP := .install.tmp
BUILD_TMP_DIR := ./.buildtmp

# Default target
.PHONY: all
all: cuda rocm gracehopper success

# Initialize environment
.PHONY: init
init: packages
	@mkdir -p $(BUILD_TMP_DIR)/repos
	@cp /etc/passwd $(BUILD_TMP_DIR)/passwd
	@cp /etc/group $(BUILD_TMP_DIR)/group
	@cp $(REPOS)/*.repo $(BUILD_TMP_DIR)/repos
	@touch $(BUILD_TMP_DIR)/init

# Download NVIDIA driver for x86_64 if not already present
$(BUILD_TMP_DIR)/NVIDIA-Linux-x86_64-$(NVIDIA_VERSION).run:
	@echo "Downloading Nvidia Drivers for x86_64..."
	@cd $(BUILD_TMP_DIR); \
		wget https://download.nvidia.com/XFree86/Linux-x86_64/$(NVIDIA_VERSION)/NVIDIA-Linux-x86_64-$(NVIDIA_VERSION).run ; \
		cd -

# Download NVIDIA driver for aarch64 if not already present
$(BUILD_TMP_DIR)/NVIDIA-Linux-aarch64-$(NVIDIA_VERSION).run:
	@echo "Downloading Nvidia Drivers for aarch64..."
	@cd $(BUILD_TMP_DIR); \
		wget https://download.nvidia.com/XFree86/Linux-aarch64/$(NVIDIA_VERSION)/NVIDIA-Linux-aarch64-$(NVIDIA_VERSION).run ; \
		cd -

# Target for CUDA build
cuda: TAG := sol-x86-rocky8-cuda-$(NVIDIA_VERSION)
cuda: init Containerfile.cuda $(BUILD_TMP_DIR)/NVIDIA-Linux-x86_64-$(NVIDIA_VERSION).run
	@echo "Building CUDA variant"
	@mkdir -p $(BUILD_TMP_DIR)/cuda/repos && cp $(REPOS)/*.repo $(BUILD_TMP_DIR)/cuda/repos
	@podman build $(PODMAN_ARGS) \
		--file ./Containerfile.cuda \
		--build-arg NVIDIA_VERSION=$(NVIDIA_VERSION) \
		--build-arg MLX_VERSION=$(MLX_VERSION)-rhel8.10-x86_64 \
		--build-arg PS1TAG=$(TAG) \
		--build-arg BUILD_TMP_DIR=$(BUILD_TMP_DIR) \
		--volume $(PWD):/mnt:O \
		--tag $(TAG):$(DATE) || { \
		echo "Error: Failed to build CUDA variant with exit code $$?. Exiting."; \
		exit 1; \
	}
	@podman save $(TAG):$(DATE) --output $(TAG).$(DATE).tar || { \
		echo "Error: Failed to save CUDA variant with exit code $$?. Exiting."; \
		exit 1; \
	}
	@echo "wwctl container import --syncuser $(PWD)/$(TAG).$(DATE).tar $(TAG).$(DATE)" >> $(INSTALL_TMP)
	@echo "wwctl container exec $(TAG).$(DATE)" /bin/passwd >> $(INSTALL_TMP)
	@make success

# Target for ROCM build
rocm: TAG := sol-x86-rocky8-rocm
rocm: init Containerfile.rocm
	@echo "Building ROCM variant"
	@mkdir -p $(BUILD_TMP_DIR)/rocm/repos && cp $(REPOS)/*.repo $(BUILD_TMP_DIR)/rocm/repos
	@podman build $(PODMAN_ARGS) \
		--file ./Containerfile.rocm \
		--build-arg MLX_VERSION=$(MLX_VERSION)-rhel8.10-x86_64 \
		--build-arg PS1TAG=$(TAG) \
		--build-arg BUILD_TMP_DIR=$(BUILD_TMP_DIR) \
		--volume $(PWD):/mnt:O \
		--tag $(TAG):$(DATE) || { \
		echo "Error: Failed to build ROCM variant with exit code $?. Exiting."; \
		exit 1; \
	}
	@podman save $(TAG):$(DATE) --output $(TAG).$(DATE).tar || { \
		echo "Error: Failed to save ROCM variant with exit code $?. Exiting."; \
		exit 1; \
	}
	@echo "wwctl container import --syncuser $(PWD)/$(TAG).$(DATE).tar $(TAG).$(DATE)" >> $(INSTALL_TMP)
	@echo "wwctl container exec $(TAG).$(DATE)" /bin/passwd >> $(INSTALL_TMP)
	@make success

# Target for GraceHopper build
gracehopper: TAG := sol-arm-rocky9-cuda-$(NVIDIA_VERSION)
gracehopper: init Containerfile.gracehopper $(BUILD_TMP_DIR)/NVIDIA-Linux-aarch64-$(NVIDIA_VERSION).run
	@echo "Building GraceHopper variant"
	@mkdir -p $(BUILD_TMP_DIR)/gracehopper/repos && cp $(ARM_REPOS)/*.repo $(BUILD_TMP_DIR)/gracehopper/repos
	@podman build $(PODMAN_ARGS) \
		--file ./Containerfile.gracehopper \
		--build-arg NVIDIA_VERSION=$(NVIDIA_VERSION) \
		--build-arg MLX_VERSION=$(MLX_VERSION)-rhel9.4-aarch64 \
		--build-arg PS1TAG=$(TAG) \
		--build-arg BUILD_TMP_DIR=$(BUILD_TMP_DIR) \
		--volume $(PWD):/mnt:O \
		--tag $(TAG):$(DATE) || { \
		echo "Error: Failed to build GraceHopper variant with exit code $?. Exiting."; \
		exit 1; \
	}
	@podman save $(TAG):$(DATE) --output $(TAG).$(DATE).tar || { \
		echo "Error: Failed to save GraceHopper variant with exit code $?. Exiting."; \
		exit 1; \
	}
	@echo "wwctl container import --syncuser $(PWD)/$(TAG).$(DATE).tar $(TAG).$(DATE)" >> $(INSTALL_TMP)
	@echo "wwctl container exec $(TAG).$(DATE)" /bin/passwd >> $(INSTALL_TMP)
	@make success

# Target for VectorEngine build
vectorengine: TAG := sol-x86-rocky8.8-vectorengine
vectorengine: init Containerfile.vectorengine
	@echo "Building VectorEngine variant"
	@mkdir -p $(BUILD_TMP_DIR)/vectorengine/repos && cp $(VECTOR_REPOS)/*.repo $(BUILD_TMP_DIR)/vectorengine/repos
	@podman build $(PODMAN_ARGS) \
		--file ./Containerfile.vectorengine \
		--build-arg MLX_VERSION=$(MLX_VERSION)-rhel8.8-x86_64 \
		--build-arg PS1TAG=$(TAG) \
		--build-arg BUILD_TMP_DIR=$(BUILD_TMP_DIR) \
		--volume $(PWD):/mnt:O \
		--tag $(TAG):$(DATE) || { \
		echo "Error: Failed to build VectorEngine variant with exit code $?. Exiting."; \
		exit 1; \
	}
	@podman save $(TAG):$(DATE) --output $(TAG).$(DATE).tar || { \
		echo "Error: Failed to save VectorEngine variant with exit code $?. Exiting."; \
		exit 1; \
	}
	@echo "wwctl container import --syncuser $(PWD)/$(TAG).$(DATE).tar $(TAG).$(DATE)" >> $(INSTALL_TMP)
	@echo "wwctl container exec $(TAG).$(DATE)" /bin/passwd >> $(INSTALL_TMP)
	@make success

# Clean up
.PHONY: clean
clean:
	@rm -rf $(BUILD_TMP_DIR) $(INSTALL_TMP) 
	@rm -rf NVIDIA*.run
	@podman image prune -f >/dev/null

# Very clean up
.PHONY: veryclean
veryclean: clean
	@initial_space=$$(df --output=avail / | tail -n 1); \
		echo "Removing old builds..."; \
		rm -f sol*.tar; \
		echo "Cleaning up and resetting podman..."; \
		for i in $$(podman container list --external | tail -n +2 | cut -d' ' -f 1); do \
			podman container rm $$i -f; \
		done; \
		rm -rf /var/lib/containers/storage/overlay/ || true; \
		sleep 1 && podman system reset -f >/dev/null; \
		final_space=$$(df --output=avail / | tail -n 1); \
        	space_freed=$$((final_space - initial_space)); \
        	space_freed_gb=$$(awk "BEGIN {printf \"%.2f\", $$space_freed / 1024 / 1024}"); \
		echo "Free disk space: $$(df -h --output=avail / | tail -n 1) (cleaned: $${space_freed_gb}G)";

# Display install log
.PHONY: success
success:
ifeq ($(wildcard $(INSTALL_TMP)),)
	@echo -e "\e[1;31mNo containers to be added to warewulf.\e[0m"
else
	@echo -e "\e[1;32m========================================================================"
	@echo "Success! Now run the following commands to import the containers into warewulf:"
	@cat $(INSTALL_TMP)
	@echo "You can also run 'make install' to execute the above commands."
	@echo -e "========================================================================\e[0m"
endif

# Install target to run import commands
.PHONY: install
install: 
ifeq ($(wildcard $(INSTALL_TMP)),)
	@echo -e "\e[1;31mNo containers to be added to warewulf.\e[0m"
else
	@echo -e "\e[1;32mRunning import commands...\e[0m"
	@bash -c "$$(cat $(INSTALL_TMP))"
#######	@$(MAKE) clean
endif
