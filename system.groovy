import com.cloudbees.plugins.credentials.SystemCredentialsProvider
import com.cloudbees.plugins.credentials.domains.DomainCredentials
import com.thoughtworks.xstream.XStream
import com.thoughtworks.xstream.converters.Converter
import com.thoughtworks.xstream.converters.MarshallingContext
import com.thoughtworks.xstream.converters.UnmarshallingContext
import com.thoughtworks.xstream.io.HierarchicalStreamReader
import com.thoughtworks.xstream.io.HierarchicalStreamWriter
import hudson.util.Secret
import jenkins.model.Jenkins

def store = Jenkins.instanceOrNull.getExtensionList(SystemCredentialsProvider.class).first().getStore()

def existing = new ArrayList<>()
for (domain in store.domains) {
  existing.add(new DomainCredentials(domain, store.getCredentials(domain)))
}

// The converter allows the output XML contains the unencrypted secrets.
def stream = new XStream()
def converter = new Converter() {
  @Override
  void marshal(Object object, HierarchicalStreamWriter writer, MarshallingContext context) {
    writer.value = Secret.toString(object as Secret)
  }

  @Override
  Object unmarshal(HierarchicalStreamReader reader, UnmarshallingContext context) { null }

  @Override
  boolean canConvert(Class type) { type == Secret.class }
}

stream.registerConverter(converter)
println stream.toXML(existing).toString()
