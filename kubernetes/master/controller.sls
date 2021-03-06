{%- from "kubernetes/map.jinja" import master with context %}
{%- from "kubernetes/map.jinja" import common with context %}
{%- if master.enabled %}

/srv/kubernetes/known_tokens.csv:
  file.managed:
  - source: salt://kubernetes/files/known_tokens.csv
  - template: jinja
  - user: root
  - group: root
  - mode: 644
  - makedirs: true

/srv/kubernetes/basic_auth.csv:
  file.managed:
  - source: salt://kubernetes/files/basic_auth.csv
  - template: jinja
  - user: root
  - group: root
  - mode: 644
  - makedirs: true

{%- if master.get('container', 'true') %}

/var/log/kube-apiserver.log:
  file.managed:
  - user: root
  - group: root
  - mode: 644

/etc/kubernetes/manifests/kube-apiserver.manifest:
  file.managed:
  - source: salt://kubernetes/files/manifest/kube-apiserver.manifest
  - template: jinja
  - user: root
  - group: root
  - mode: 644
  - makedirs: true
  - dir_mode: 755

/etc/kubernetes/manifests/kube-controller-manager.manifest:
  file.managed:
    - source: salt://kubernetes/files/manifest/kube-controller-manager.manifest
    - template: jinja
    - user: root
    - group: root
    - mode: 644
    - makedirs: true
    - dir_mode: 755

/var/log/kube-controller-manager.log:
  file.managed:
    - user: root
    - group: root
    - mode: 644

/etc/kubernetes/manifests/kube-scheduler.manifest:
  file.managed:
    - source: salt://kubernetes/files/manifest/kube-scheduler.manifest
    - template: jinja
    - user: root
    - group: root
    - mode: 644
    - makedirs: true
    - dir_mode: 755

/var/log/kube-scheduler.log:
  file.managed:
    - user: root
    - group: root
    - mode: 644

{%- else %}

/etc/default/kube-apiserver:
  file.managed:
    - user: root
    - group: root
    - mode: 644
    - contents: >-
        DAEMON_ARGS="
        --admission-control=NamespaceLifecycle,LimitRanger,ServiceAccount,ResourceQuota,DefaultStorageClass
        --allow-privileged=True
        --basic-auth-file=/srv/kubernetes/basic_auth.csv
        --bind-address={{ master.apiserver.get('bind_address', master.apiserver.address) }}
        --client-ca-file=/etc/kubernetes/ssl/ca-{{ master.ca }}.crt
        --etcd-quorum-read=true
        --insecure-bind-address={{ master.apiserver.insecure_address }}
        --insecure-port={{ master.apiserver.insecure_port }}
        --secure-port={{ master.apiserver.secure_port }}
        --service-cluster-ip-range={{ master.service_addresses }}
        --tls-cert-file=/etc/kubernetes/ssl/kubernetes-server.crt
        --tls-private-key-file=/etc/kubernetes/ssl/kubernetes-server.key
        --token-auth-file=/srv/kubernetes/known_tokens.csv
        --apiserver-count={{ master.apiserver.get('count', 1) }}
        --v={{ master.get('verbosity', 2) }}
        --advertise-address={{ master.apiserver.address }}
        --etcd-servers=
{%- for member in master.etcd.members -%}
          http{% if master.etcd.get('ssl', {}).get('enabled') %}s{% endif %}://{{ member.host }}:{{ member.get('port', 4001) }}{% if not loop.last %},{% endif %}
{%- endfor %}
{%- if master.etcd.get('ssl', {}).get('enabled') %}
        --etcd-cafile /var/lib/etcd/ca.pem
        --etcd-certfile /var/lib/etcd/etcd-client.crt
        --etcd-keyfile /var/lib/etcd/etcd-client.key
{%- endif %}
{%- if master.apiserver.node_port_range is defined %}
        --service-node-port-range {{ master.apiserver.node_port_range }}
{%- endif %}
{%- if common.get('cloudprovider', {}).get('enabled') %}
        --cloud-provider={{ common.cloudprovider.provider }}
{%- if common.get('cloudprovider', {}).get('provider') == 'openstack' %}
        --cloud-config=/etc/kubernetes/cloud-config.conf
{%- endif %}
{%- endif %}
{%- for key, value in master.get('apiserver', {}).get('daemon_opts', {}).iteritems() %}
        --{{ key }}={{ value }}
{%- endfor %}"

{% for component in ['scheduler', 'controller-manager'] %}

/etc/kubernetes/{{ component }}.kubeconfig:
  file.managed:
    - source: salt://kubernetes/files/kube-{{ component }}/{{ component }}.kubeconfig
    - template: jinja
    - user: root
    - group: root
    - mode: 644
    - makedirs: True
    - watch_in:
        - service: master_services

{% endfor %}

/etc/default/kube-controller-manager:
  file.managed:
    - user: root
    - group: root
    - mode: 644
    - contents: >-
        DAEMON_ARGS="
        --cluster-name=kubernetes
        --kubeconfig /etc/kubernetes/controller-manager.kubeconfig
        --leader-elect=true
        --root-ca-file=/etc/kubernetes/ssl/ca-{{ master.ca }}.crt
        --service-account-private-key-file=/etc/kubernetes/ssl/kubernetes-server.key
{%- if common.get('cloudprovider', {}).get('enabled') %}
        --cloud-provider={{ common.cloudprovider.provider }}
{%- if common.get('cloudprovider', {}).get('provider') == 'openstack' %}
        --cloud-config=/etc/kubernetes/cloud-config.conf
{%- endif %}
{%- endif %}
        --v={{ master.get('verbosity', 2) }}
{%- for key, value in master.get('controller_manager', {}).get('daemon_opts', {}).iteritems() %}
        --{{ key }}={{ value }}
{% endfor %}"

/etc/default/kube-scheduler:
  file.managed:
    - user: root
    - group: root
    - mode: 644
    - contents: >-
        DAEMON_ARGS="
        --kubeconfig /etc/kubernetes/scheduler.kubeconfig
        --leader-elect=true
        --v={{ master.get('verbosity', 2) }}
{%- for key, value in master.get('scheduler', {}).get('daemon_opts', {}).iteritems() %}
        --{{ key }}={{ value }}
{% endfor %}"

/etc/systemd/system/kube-apiserver.service:
  file.managed:
  - source: salt://kubernetes/files/systemd/kube-apiserver.service
  - template: jinja
  - user: root
  - group: root
  - mode: 644

/etc/systemd/system/kube-scheduler.service:
  file.managed:
  - source: salt://kubernetes/files/systemd/kube-scheduler.service
  - template: jinja
  - user: root
  - group: root
  - mode: 644

/etc/systemd/system/kube-controller-manager.service:
  file.managed:
  - source: salt://kubernetes/files/systemd/kube-controller-manager.service
  - template: jinja
  - user: root
  - group: root
  - mode: 644

{% for filename in ['kubernetes-server.crt', 'kubernetes-server.key', 'kubernetes-server.pem'] %}

/etc/kubernetes/ssl/{{ filename }}:
  file.managed:
    - source: salt://{{ master.get('cert_source','_certs/kubernetes') }}/{{ filename }}
    - user: root
    {%- if pillar.get('haproxy', {}).get('proxy', {}).get('enabled') %}
    - group: haproxy
    {%- else %}
    - group: root
    {%- endif %}
    - mode: 640
    - watch_in:
      - service: master_services

{% endfor %}

master_services:
  service.running:
  - names: {{ master.services }}
  - enable: True
  - watch:
    - file: /etc/default/kube-apiserver
    - file: /etc/default/kube-scheduler
    - file: /etc/default/kube-controller-manager
    - file: /usr/bin/hyperkube

{%- endif %}


{%- for name,namespace in master.namespace.iteritems() %}

{%- if namespace.enabled %}

{%- set date = salt['cmd.run']('date "+%FT%TZ"') %}

kubernetes_namespace_create_{{ name }}:
  cmd.run:
    - name: kubectl create ns "{{ name }}"
    - name: kubectl get ns -o=custom-columns=NAME:.metadata.name | grep -v NAME | grep "{{ name }}" > /dev/null || kubectl create ns "{{ name }}"
    {%- if grains.get('noservices') %}
    - onlyif: /bin/false
    {%- endif %}

{%- else %}

kubernetes_namespace_delete_{{ name }}:
  cmd.run:
    - name: kubectl get ns -o=custom-columns=NAME:.metadata.name | grep -v NAME | grep "{{ name }}" > /dev/null && kubectl delete ns "{{ name }} || true"

{%- endif %}

{%- endfor %}

{%- if master.registry.secret is defined %}

{%- for name,registry in master.registry.secret.iteritems() %}

{%- if registry.enabled %}

/registry/secrets/{{ registry.namespace }}/{{ name }}:
  etcd.set:
    - value: '{"kind":"Secret","apiVersion":"v1","metadata":{"name":"{{ name }}","namespace":"{{ registry.namespace }}"},"data":{".dockerconfigjson":"{{ registry.key }}"},"type":"kubernetes.io/dockerconfigjson"}'
    {%- if grains.get('noservices') %}
    - onlyif: /bin/false
    {%- endif %}

{%- else %}

/registry/secrets/{{ registry.namespace }}/{{ name }}:
  etcd.rm

{%- endif %}

{%- endfor %}

{%- endif %}

{%- endif %}
