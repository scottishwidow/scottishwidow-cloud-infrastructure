TERRAFORM        ?= terraform
ANSIBLE_PLAYBOOK ?= ansible-playbook
TF_ARGS          ?=
OPENSSL          ?= openssl

REQUIRED_ENV  := AWS_PROFILE HONEYNET_HCLOUD_TOKEN

APPLY_ORDER   := corpus network sensor honeypots
DESTROY_ORDER := honeypots sensor network
ALL_STACKS    := bootstrap $(APPLY_ORDER)

DIR_bootstrap  := bootstrap
DIR_corpus     := ../../aws/honeynet/corpus
DIR_network    := network
DIR_sensor     := sensor
DIR_honeypots  := honeypots

PKI_DIR          := pki
CA_KEY           := $(PKI_DIR)/ca.key
CA_CERT          := $(PKI_DIR)/ca.crt
CA_VALIDITY_DAYS := 180
CORPUS_VARS      := $(DIR_corpus)/sensor.auto.tfvars

export HCLOUD_TOKEN := $(HONEYNET_HCLOUD_TOKEN)

export TF_VAR_honeypot_1_private_ip := 10.20.0.11

export TF_VAR_proxy_port := 3128

export TF_VAR_honeypot_port_redirects := {"21":2121,"22":2222,"23":2223,"80":8080}

.NOTPARALLEL:
.PHONY: init apply destroy inventory corpus-vars configure verify

init: $(addprefix init-,$(APPLY_ORDER))
apply: $(addprefix apply-,$(APPLY_ORDER))
destroy: $(addprefix destroy-,$(DESTROY_ORDER))
	rm -rf $(PKI_DIR)

plan-corpus apply-corpus: $(CA_CERT)

$(CA_CERT):
	mkdir -p $(PKI_DIR)
	chmod 700 $(PKI_DIR)
	umask 077 && $(OPENSSL) req -x509 -noenc -newkey ec -pkeyopt ec_paramgen_curve:P-256 \
		-keyout $(CA_KEY) -out $@.tmp -days $(CA_VALIDITY_DAYS) -sha256 \
		-subj "/CN=honeynet-sensor-ca" \
		-addext "basicConstraints=critical,CA:TRUE,pathlen:0" \
		-addext "keyUsage=critical,keyCertSign,cRLSign"
	mv $@.tmp $@

corpus-vars:
	$(call require_env)
	printf 'sensor_public_ipv4 = "%s"\n' "$$($(TERRAFORM) -chdir=$(call stack_dir,bootstrap) output -raw sensor_public_ipv4)" > $(CORPUS_VARS).tmp
	grep -qE '^sensor_public_ipv4 = "[0-9.]+"$$' $(CORPUS_VARS).tmp
	mv $(CORPUS_VARS).tmp $(CORPUS_VARS)

inventory:
	$(call require_env)
	$(TERRAFORM) -chdir=$(call stack_dir,sensor) output -json ansible_inventory > ansible/inventory/sensor.json.tmp
	$(TERRAFORM) -chdir=$(call stack_dir,honeypots) output -json ansible_inventory > ansible/inventory/honeypots.json.tmp
	mv ansible/inventory/sensor.json.tmp ansible/inventory/sensor.json
	mv ansible/inventory/honeypots.json.tmp ansible/inventory/honeypots.json
	rm -f ansible/.known_hosts

configure: inventory
	cd ansible && $(ANSIBLE_PLAYBOOK) playbooks/site.yml

verify:
	cd ansible && $(ANSIBLE_PLAYBOOK) playbooks/verify.yml

init-%:
	$(call require_env)
	$(TERRAFORM) -chdir=$(call stack_dir,$*) init -input=false $(TF_ARGS)

plan-%:
	$(call require_env)
	$(TERRAFORM) -chdir=$(call stack_dir,$*) plan $(TF_ARGS)

apply-%:
	$(call require_env)
	$(TERRAFORM) -chdir=$(call stack_dir,$*) apply $(TF_ARGS)

destroy-%:
	$(call require_env)
	$(TERRAFORM) -chdir=$(call stack_dir,$*) destroy $(TF_ARGS)

stack_dir   = $(or $(DIR_$(1)),$(error Unknown stack '$(1)'. Allowed: $(ALL_STACKS)))
require_env = $(foreach var,$(REQUIRED_ENV),$(if $($(var)),,$(error $(var) is not set)))
