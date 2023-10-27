FROM envoyproxy/envoy:v1.27-latest
RUN apt update && apt install tcpdump -y
COPY tcpdump.sh /tcpdump.sh
RUN chmod +x /tcpdump.sh