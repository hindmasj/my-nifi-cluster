package io.github.hindmasj.nifi;

import java.util.List;

import org.apache.nifi.util.MockFlowFile;
import org.apache.nifi.util.TestRunner;
import org.apache.nifi.util.TestRunners;

import static org.junit.Assert.*;
import org.junit.Before;
import org.junit.Test;


public class TextApprovalProcessorTest {

    private TestRunner testRunner;

    @Before
    public void init() {
        testRunner = TestRunners.newTestRunner(TextApprovalProcessor.class);
    }

    @Test
    public void testSimpleString() {
      testRunner.enqueue("hello");
      testRunner.run();
      testRunner.assertAllFlowFilesTransferred(TextApprovalProcessor.SUCCESS);

      List<MockFlowFile> output=
        testRunner.getFlowFilesForRelationship(TextApprovalProcessor.SUCCESS);
      assertNotNull(output);
      assertEquals(output.size(),1);
      MockFlowFile flowFile=output.get(0);

      flowFile.assertContentEquals("hello APPROVED\n");
    }

    @Test
    public void testComplexString() {
      testRunner.enqueue("hello\nworld");
      testRunner.run();
      testRunner.assertAllFlowFilesTransferred(TextApprovalProcessor.SUCCESS);

      List<MockFlowFile> output=
        testRunner.getFlowFilesForRelationship(TextApprovalProcessor.SUCCESS);
      assertNotNull(output);
      assertEquals(output.size(),1);
      MockFlowFile flowFile=output.get(0);

      flowFile.assertContentEquals("hello APPROVED\nworld APPROVED\n");
    }

    @Test
    public void testMultipleFlows() {
      testRunner.enqueue("hello");
      testRunner.enqueue("world");
      // Make sure you run the onTrigger twice for 2 flow files 
      testRunner.run(2);
      testRunner.assertAllFlowFilesTransferred(TextApprovalProcessor.SUCCESS);

      List<MockFlowFile> output=
        testRunner.getFlowFilesForRelationship(TextApprovalProcessor.SUCCESS);
      assertNotNull(output);
      assertEquals(output.size(),2);

      MockFlowFile flowFile=output.get(0);
      flowFile.assertContentEquals("hello APPROVED\n");

      flowFile=output.get(1);
      flowFile.assertContentEquals("world APPROVED\n");
    }

}
