package org.nd4j.camel.kafka;

import lombok.AllArgsConstructor;
import lombok.Builder;
import org.apache.camel.Exchange;
import org.apache.camel.Processor;
import org.apache.camel.builder.RouteBuilder;
import org.apache.camel.component.kafka.KafkaConstants;
import org.apache.commons.net.util.Base64;
import org.nd4j.linalg.api.ndarray.INDArray;
import org.nd4j.linalg.factory.Nd4j;
import org.nd4j.serde.base64.Nd4jBase64;

import java.io.ByteArrayOutputStream;
import java.io.DataOutputStream;
import java.util.UUID;

/**
 * Sends a test ndarray
 * to kafka
 *
 * @author Adam Gibson
 */
@AllArgsConstructor
@Builder
public class Nd4jKafkaRoute extends RouteBuilder {
    private KafkaConnectionInformation kafkaConnectionInformation;

    @Override
    public void configure() throws Exception {
        final String kafkaUri = kafkaConnectionInformation.kafkaUri();
        from("direct:start").process(new Processor() {
            @Override
            public void process(Exchange exchange) throws Exception {
                final INDArray arr = (INDArray) exchange.getIn().getBody();
                ByteArrayOutputStream bos = new ByteArrayOutputStream();
                DataOutputStream dos = new DataOutputStream(bos);
                Nd4j.write(arr, dos);
                byte[] bytes = bos.toByteArray();
                String base64 = Base64.encodeBase64String(bytes);
                exchange.getIn().setBody(base64, String.class);
                String id = UUID.randomUUID().toString();
                exchange.getIn().setHeader(KafkaConstants.KEY, id);
                exchange.getIn().setHeader(KafkaConstants.PARTITION_KEY, id);
            }
        }).to(kafkaUri);

        from(kafkaUri).process(new Processor() {
            @Override
            public void process(Exchange exchange) throws Exception {
                byte[] body2 = (byte[]) exchange.getIn().getBody();
                String body = new String(body2);
                INDArray arr = Nd4jBase64.fromBase64(body);
                exchange.getIn().setBody(arr);
            }
        }).to("direct:receive");
    }
}
