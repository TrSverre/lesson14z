FROM ubuntu:18.04 as build
RUN apt update
RUN apt install openjdk-11-jdk -y
RUN apt install git maven -y
RUN git clone https://github.com/TrSverre/lesson12rep.git -b master
RUN mvn -f lesson12rep/pom.xml package

FROM tomcat:9.0.8-jre8-alpine
COPY --from=build lesson12rep/target/App42PaaS-Java-MySQL-Sample-0.0.1-SNAPSHOT.war /usr/local/tomcat/webapps
COPY --from=build lesson12rep/WebContent/Config.properties /usr/local/tomcat/ROOT/