{#- Portainer API Details #}
{%- set portainer_api_url = "http://127.0.0.1:9000/api" %}
{%- set portainer_api_login = "admin" %}{# TODO: This should probably come from a secure pillar #}
{%- set portainer_api_password = "REDACTED" %}{# TODO: This should probably come from a secure pillar #}
{%- set docker_endpoint_id = 2 %}{# TODO: Autodetect if not sepcified #}

{#- Container Details #}
{%- set container_name = "hello-world-1" %}
{%- set container_image = "hello-world" %}
{%- set container_image_tag = "latest" %}

{#- 
  The login process happens while the template is still being rendered.  This
  allows us to capture the JWT and include it in the request headers for
  states.
#}
{%- set portainer_jwt = "" %}
{%- set portainer_login = salt['http.query'](portainer_api_url ~ "/auth",method="POST",data_file="/tmp/auth.jinja",template_dict={ "Username": portainer_api_login,"Password": portainer_api_password },verify_ssl=False,data_renderer="jinja",data_render=True,text_out="/tmp/auth.token",status=200,decode_body=True) %}
{%- if 'body' in portainer_login %}
  {%- set portainer_jwt = (portainer_login['body'] | load_json)['jwt'] %}
{%- endif %}

{%- if portainer_jwt != "" %}
portainer_login_result:
  test.succeed_without_changes:
    - name: portainer_jwt
    # comment: {{ portainer_jwt }}
    - comment: "Successfully logged into Portainer and received a authentication token"
{%- else %}
portainer_login_result:
  test.fail_without_changes:
    - name: portainer_jwt
    - comment: "Unable to log into Portainer with the provided credentails: '{{ portainer_login }}'"
{%- endif %}

portainer.get_image:
  http.query:
    - name: "{{ portainer_api_url }}/endpoints/{{ docker_endpoint_id }}/docker/images/create?fromImage={{ container_image }}"
    - method: POST
    - data_file: "/home/ubuntu/portainer_salt_experiments/files/endpoints.docker.images.create.jinja"
    - template_dict:
        tag: "{{ container_image_tag }}"
    - verify_ssl: False
    - header_dict: {'Authorization': 'Bearer {{ portainer_jwt }}', 'Content-Type': 'application/json'}
    - data_renderer: "jinja"
    - data_render: true
    - status: 200
    - onlyif:
      - fun: http.query
        args:
          - "{{ portainer_api_url }}/endpoints/{{ docker_endpoint_id }}/docker/images/{{ container_image }}:{{ container_image_tag }}/json"
        method: GET
        verify_ssl: False
        header_dict: {'Authorization': 'Bearer {{ portainer_jwt }}'}
        get_return: status
    - require:
      - test: portainer_jwt

portainer.deploy_container:
  http.query:
    - name: "{{ portainer_api_url }}/endpoints/{{ docker_endpoint_id }}/docker/containers/create?name={{ container_name }}"
    - method: POST
    - data_file: "/home/ubuntu/portainer_salt_experiments/files/endpoints.docker.containers.create.jinja"
    - template_dict:
        name: "{{ container_name }}"
        image: "{{ container_image }}"
        hostconfig: '{ "PortBindings": { "80/tcp": [{ "HostPort": "8080" }] } }'
    - verify_ssl: False
    - header_dict: {'Authorization': 'Bearer {{ portainer_jwt }}', 'Content-Type': 'application/json'}
    - data_renderer: "jinja"
    - data_render: true
    - status: 200
    - onlyif:
      {#-
        Using 'http.query' here is using the "runner" module, not the "state"
        module.  This means that state module features like "status" and
        "match" do not work.  "get_return: status" seems to work based on
        whether the response was a simple 2XX "OK" or anything else.
      #}
      - fun: http.query
        args:
          - "{{ portainer_api_url }}/endpoints/{{ docker_endpoint_id }}/docker/containers/{{ container_name }}/json?test"
        method: GET
        verify_ssl: False
        header_dict: {'Authorization': 'Bearer {{ portainer_jwt }}'}
        get_return: status
    - require:
      - http: "{{ portainer_api_url }}/endpoints/{{ docker_endpoint_id }}/docker/images/create?fromImage={{ container_image }}"

portainer.start_container:
  http.query:
    - name: "{{ portainer_api_url }}/endpoints/{{ docker_endpoint_id }}/docker/containers/{{ container_name }}/start"
    - method: POST
    - data_file: "/home/ubuntu/portainer_salt_experiments/files/endpoints.docker.containers.start.jinja"
    - data_renderer: "jinja"
    - data_render: true
    - verify_ssl: False
    - header_dict: {'Authorization': 'Bearer {{ portainer_jwt }}', 'Content-Type': 'application/json'}
    - status:
        - 200
        - 204
    - status_type: list
    - require:
      - test: portainer_jwt
    - onlyif:
      {#-
        TODO: Without matching for "running: true" I'm not sure how to make
        this work.
      #}
      - fun: http.query
        args:
          - "{{ portainer_api_url }}/endpoints/{{ docker_endpoint_id }}/docker/containers/{{ container_name }}/json?test"
        method: GET
        verify_ssl: False
        header_dict: {'Authorization': 'Bearer {{ portainer_jwt }}'}
        get_return: status
