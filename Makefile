ifndef PYTHON_VERSION
override PYTHON_VERSION = 3.10
endif

BRANCH_NAME := $(shell git rev-parse --abbrev-ref HEAD)
PYTHON_CMD := python${PYTHON_VERSION}
CURDIR := $(PWD)
PG_DATA := $(PWD)/pgdata
DB_HOST := $(shell grep '^\s*DATABASE_HOST' .env | tail -1 | cut -d= -f2)

ifndef PYTHONPATH
override PYTHONPATH = $(shell ${PYTHON_CMD} -c "import os, sys; print(os.path.dirname(sys.executable))")
endif

export PROJECT_NAME := $(notdir ${CURDIR})
export APP_NAME := src
export PROJECT_DIR: ${CURDIR}
export PIP_IGNORE_INSTALLED: 1

# Color
Color_Off='\033[0m'       # Text Reset

# Regular Colors
Black='\033[0;30m'        # Black
Red='\033[0;31m'          # Red
Green='\033[0;32m'        # Green
Yellow='\033[0;33m'       # Yellow
Blue='\033[0;34m'         # Blue
Purple='\033[0;35m'       # Purple
Cyan='\033[0;36m'         # Cyan
White='\033[0;37m'        # White

define COLORED_ECHO
  @echo "$1$2${Color_Off}"
endef

## Docker
export TAG_NAME := ${PROJECT_NAME}
ifdef t
override TAG_NAME := "gitlabregistry.devct.cz/red-python/${PROJECT_NAME}:$t"
endif

define DOCKER_BUILD
    @echo "Build docker image with tag name: '${TAG_NAME}'"
    @docker build . -t ${TAG_NAME} --build-arg PYTHON_VERSION=${PYTHON_VERSION} --file 'Dockerfile' --network=host --platform x86_64 $1;
endef

define DOCKER_RUN
    $(call DOCKER_STOP)
    @echo "Run docker with tag name: '${TAG_NAME}'"
    @docker run --env-file .env -a stdout --network=host $1 -ti ${TAG_NAME} $2
endef

define DOCKER_STOP
	@echo "Stop docker image: ${TAG_NAME}"
	@docker stop $$(docker ps -a -q --filter ancestor='${TAG_NAME}') || true
endef

define DOCKER_REMOVE
	$(call DOCKER_STOP)
	@echo "Remove docker images: ${TAG_NAME}"
	@docker rmi $$(docker images | grep '${TAG_NAME}')
endef

define CHECK_PUBLISH_TAG_NAME
@if [ -z '${t}' ] || [ '${TAG_NAME}' = '${PROJECT_NAME}' ]; then \
	echo "Enter the tag name, example: make docker-push t=latest OR t=1.1.0.alpha" ; \
    exit 1; \
else \
    git fetch --tags; \
    export tag_exists=$(git tag | grep ${t}) ;\
    if [ ! -z "${tag_exists}" ]; then \
        echo || echo "Tag: '${tag_exists}' exists !" >&2 ;\
        exit 1; \
    fi \
fi
endef

define DOCKER_PUSH_TAG
	$(call CHECK_PUBLISH_TAG_NAME)
	$(call DOCKER_BUILD)
  @echo "Push docker image with tag name: '${TAG_NAME}'"
	@docker login gitlabregistry.devct.cz; \
	@docker push '${TAG_NAME}'; \
	@git tag -a ${AG_NAME} -m ${PUBLISH_TAG_NAME}; \
	@git push origin ${BRANCH_NAME} -f; \
	# docker logout gitlabregistry.devct.cz;
endef

define DOCKER_SHOW_IMAGES
	@echo "Run show all docker images by name: ${TAG_NAME}"
	@docker container ls -a | grep "${TAG_NAME}" || true
endef


.PHONY: install install-poetry install-deploy uninstall reinstall reinstall-pre-commit update
install-poetry:
	$(call COLORED_ECHO,${Green},'Run install & update poetry and another packages')
	${PYTHON_CMD} -m pip install --user --upgrade py pip virtualenv poetry wheel setuptools 
	poetry env use ${PYTHON_CMD}
	poetry config --local
install: install-poetry
	@echo "Run install-dev ${PROJECT_NAME}"
	echo ${PYTHON_CMD}
	poetry install --no-root --no-interaction
install-deploy: install-poetry
	@echo "Run test install for deploy"
	@if [ -f "poetry.lock" ]; then \
	  poetry install --only main --no-interaction --no-ansi; \
	else \
	  echo "Missing poetry.lock !"; \
	  exit 1; \
	fi
uninstall:
	@echo "Run uninstall-dev"
	@pre-commit uninstall
	@rm -rf .venv poetry.lock
	@poetry cache clear --all reposysct
reinstall: uninstall install
reinstall-pre-commit:
	@echo "Reinstall pre-commit"
	@pre-commit uninstall
	@pre-commit install
	@pre-commit autoupdate
update:
	@echo "Run update packages"
	@poetry update --dry-run

