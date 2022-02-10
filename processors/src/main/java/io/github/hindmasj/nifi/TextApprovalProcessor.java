package io.github.hindmasj.nifi;

import java.nio.charset.StandardCharsets;
import java.util.HashSet;
import java.util.Set;
import java.util.concurrent.atomic.AtomicReference;

import org.apache.commons.io.IOUtils;

import org.apache.nifi.annotation.behavior.*;
import org.apache.nifi.annotation.behavior.InputRequirement.Requirement;
import org.apache.nifi.annotation.documentation.*;

import org.apache.nifi.flowfile.FlowFile;

import org.apache.nifi.processor.AbstractProcessor;
import org.apache.nifi.processor.ProcessContext;
import org.apache.nifi.processor.ProcessSession;
import org.apache.nifi.processor.ProcessorInitializationContext;
import org.apache.nifi.processor.Relationship;
import org.apache.nifi.processor.exception.ProcessException;

@EventDriven
@Tags({"Text"})
@CapabilityDescription("Adds an approval string to any message")
@InputRequirement(Requirement.INPUT_REQUIRED)
@SupportsBatching
public class TextApprovalProcessor extends AbstractProcessor{

  public static final String APPROVED=" APPROVED";
  public static final String MESSAGE_DELIM="\n";

  public static final Relationship SUCCESS = new Relationship.Builder()
  .name("Success")
  .description("The processing has completed successfully.")
  .build();

  public static final Relationship FAILURE = new Relationship.Builder()
  .name("Failure")
  .description("There has been an issue processing the messages.")
  .build();

  private Set<Relationship> relationships =
  new HashSet<Relationship>();

  /** Allows NiFi to get the current relationships. */
  @Override
  public Set<Relationship> getRelationships() {
    return this.relationships;
  }

  /** Allows NiFi to set the the relationships. */
  public void setRelationships(Set<Relationship> relationships) {
    this.relationships = relationships;
  }

  /** Initialises the relationships. */
  @Override
  protected void init(final ProcessorInitializationContext context) {
    this.relationships.add(SUCCESS);
    this.relationships.add(FAILURE);
  }

  /** The entry point for processing. */
  @Override
  public void onTrigger(final ProcessContext context, final ProcessSession session) throws ProcessException {
    FlowFile flowFile = session.get();
    if (flowFile == null) {return;}
    final AtomicReference<String[]> response = new AtomicReference<String[]>();

    try{

      session.read(flowFile, in -> {
        String flowContent = IOUtils.toString(in,StandardCharsets.UTF_8);
        String[] flowMessages = flowContent.split(MESSAGE_DELIM);
        for(int i=0;i<flowMessages.length;i++){
          flowMessages[i]=flowMessages[i]+APPROVED;
        }
        response.set(flowMessages);
      });

      session.transfer(
        session.write(
          flowFile,
          out->out.write(stringArrayToByteArray(response.get()))
        ),
        SUCCESS
      );

    } catch (Exception e) {
      getLogger().error("Unhandled exception: "+e.getMessage());
      getLogger().debug("Stack Trace: ", e.getStackTrace());
      session.transfer(flowFile, FAILURE);
    }

  }

  private byte[] stringArrayToByteArray(String[] array) {
    StringBuffer buffer = new StringBuffer();
    for(String s : array){
      buffer.append(s);
      buffer.append(MESSAGE_DELIM);
    }
    return buffer.toString().getBytes();
  }

}
