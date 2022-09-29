sudo apt update
sudo apt install default-jre -y
sudo apt install default-jdk -y

curl -fsSL https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -
echo "deb https://artifacts.elastic.co/packages/7.x/apt stable main" | sudo tee -a /etc/apt/sources.list.d/elastic-7.x.list
sudo apt update
sudo apt install elasticsearch -y
sudo sed -i "/network.host/anetwork.host: localhost"  /etc/elasticsearch/elasticsearch.yml
sudo systemctl start elasticsearch
sudo systemctl enable elasticsearch
curl -X GET "localhost:9200"

sudo apt install kibana -y
sudo sed -i "/server.host/aserver.host: 0.0.0.0"  /etc/kibana/kibana.yml
sudo systemctl enable kibana
sudo systemctl start kibana

sudo apt install logstash -y
touch 02-beats-input.conf
cat <<EOF >>02-beats-input.conf
input {
  beats {
    port => 5044
  }
}
EOF
sudo cp 02-beats-input.conf /etc/logstash/conf.d/02-beats-input.conf
touch 30-elasticsearch-output.conf
cat <<EOF >>30-elasticsearch-output.conf
output {
  if [@metadata][pipeline] {
	elasticsearch {
  	hosts => ["localhost:9200"]
  	manage_template => false
  	index => "%{[@metadata][beat]}-%{[@metadata][version]}-%{+YYYY.MM.dd}"
  	pipeline => "%{[@metadata][pipeline]}"
	}
  } else {
	elasticsearch {
  	hosts => ["localhost:9200"]
  	manage_template => false
  	index => "%{[@metadata][beat]}-%{[@metadata][version]}-%{+YYYY.MM.dd}"
	}
  }
}
EOF
sudo cp 30-elasticsearch-output.conf /etc/logstash/conf.d/30-elasticsearch-output.conf
sudo systemctl start logstash
sudo systemctl enable logstash

sudo apt install filebeat -y
sudo sed -i "/output.logstash:/s/^#//g" /etc/filebeat/filebeat.yml
sudo sed -i "/localhost:5044/s/\#//g" /etc/filebeat/filebeat.yml
sudo sed -i  "/^output.elasticsearch/ s/./#&/" /etc/filebeat/filebeat.yml
sudo sed -i  "/localhost:9200/ s/./#&/" /etc/filebeat/filebeat.yml
sudo filebeat modules enable system
sudo filebeat setup --pipelines --modules system
sudo filebeat setup --index-management -E output.logstash.enabled=false -E 'output.elasticsearch.hosts=["localhost:9200"]'
sudo filebeat setup -E output.logstash.enabled=false -E output.elasticsearch.hosts=['localhost:9200'] -E setup.kibana.host=localhost:5601
sudo systemctl start filebeat
sudo systemctl enable filebeat
curl -XGET 'http://localhost:9200/filebeat-*/_search?pretty'
