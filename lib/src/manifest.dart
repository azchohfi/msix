import 'dart:io';
import 'capabilities.dart';
import 'utils/injector.dart';
import 'utils/log.dart';
import 'configuration.dart';
import 'utils/extensions.dart';

class Manifest {
  Configuration _config;

  Manifest() : _config = injector.get<Configuration>();

  void generateAppxManifest() {
    const taskName = 'generate appx manifest';
    Log.startingTask(taskName);

    var manifestContent = '''<?xml version="1.0" encoding="utf-8"?>
  <Package xmlns="http://schemas.microsoft.com/appx/manifest/foundation/windows10" 
          xmlns:uap="http://schemas.microsoft.com/appx/manifest/uap/windows10" 
          xmlns:uap2="http://schemas.microsoft.com/appx/manifest/uap/windows10/2" 
          xmlns:uap3="http://schemas.microsoft.com/appx/manifest/uap/windows10/3" 
          xmlns:uap4="http://schemas.microsoft.com/appx/manifest/uap/windows10/4" 
          xmlns:uap6="http://schemas.microsoft.com/appx/manifest/uap/windows10/6" 
          xmlns:uap7="http://schemas.microsoft.com/appx/manifest/uap/windows10/7" 
          xmlns:uap8="http://schemas.microsoft.com/appx/manifest/uap/windows10/8" 
          xmlns:uap10="http://schemas.microsoft.com/appx/manifest/uap/windows10/10" 
          xmlns:iot="http://schemas.microsoft.com/appx/manifest/iot/windows10" 
          xmlns:desktop="http://schemas.microsoft.com/appx/manifest/desktop/windows10" 
          xmlns:desktop2="http://schemas.microsoft.com/appx/manifest/desktop/windows10/2" 
          xmlns:desktop6="http://schemas.microsoft.com/appx/manifest/desktop/windows10/6" 
          xmlns:rescap="http://schemas.microsoft.com/appx/manifest/foundation/windows10/restrictedcapabilities" 
          xmlns:rescap3="http://schemas.microsoft.com/appx/manifest/foundation/windows10/restrictedcapabilities/3" 
          xmlns:rescap6="http://schemas.microsoft.com/appx/manifest/foundation/windows10/restrictedcapabilities/6" 
          xmlns:com="http://schemas.microsoft.com/appx/manifest/com/windows10" 
          xmlns:com2="http://schemas.microsoft.com/appx/manifest/com/windows10/2" 
          xmlns:com3="http://schemas.microsoft.com/appx/manifest/com/windows10/3" 
          IgnorableNamespaces="uap3 desktop">
    <Identity Name="${_config.identityName}" Version="${_config.msixVersion}"
              Publisher="${_config.publisher!.replaceAll(' = ', '=')}" ProcessorArchitecture="${_config.architecture}" />
    <Properties>
      <DisplayName>${_config.displayName}</DisplayName>
      <PublisherDisplayName>${_config.publisherName}</PublisherDisplayName>
      <Logo>Images\\StoreLogo.png</Logo>
      <Description>${_config.appDescription}</Description>
    </Properties>
    <Resources>
      ${_config.languages!.map((language) => '<Resource Language="$language" />').join('')}
    </Resources>
    <Dependencies>
      <TargetDeviceFamily Name="Windows.Desktop" MinVersion="10.0.17763.0" MaxVersionTested="10.0.19042.630" />
    </Dependencies>
    <Capabilities>
      ${_getCapabilities()}
  </Capabilities>
    <Applications>
      <Application Id="${_config.appName!.replaceAll('_', '')}" Executable="${_config.executableFileName}" EntryPoint="Windows.FullTrustApplication">
        <uap:VisualElements BackgroundColor="transparent"
          DisplayName="${_config.displayName}" Square150x150Logo="Images\\Square150x150Logo.png"
          Square44x44Logo="Images\\Square44x44Logo.png" Description="${_config.appDescription}">
          <uap:DefaultTile ShortName="${_config.displayName}" Square310x310Logo="Images\\LargeTile.png"
          Square71x71Logo="Images\\SmallTile.png" Wide310x150Logo="Images\\Wide310x150Logo.png">
            <uap:ShowNameOnTiles>
              <uap:ShowOn Tile="square150x150Logo"/>
              <uap:ShowOn Tile="square310x310Logo"/>
              <uap:ShowOn Tile="wide310x150Logo"/>
            </uap:ShowNameOnTiles>
          </uap:DefaultTile>
          <uap:SplashScreen Image="Images\\SplashScreen.png"/>
          <uap:LockScreen BadgeLogo="Images\\BadgeLogo.png" Notification="badge"/>
        </uap:VisualElements>
        ${_getExtensions()}
      </Application>
    </Applications>
  </Package>''';

    //clear empty rows
    manifestContent = manifestContent.replaceAll('    \n', '');

    var appxManifestPath = '${_config.buildFilesFolder}\\AppxManifest.xml';
    try {
      File(appxManifestPath).createSync();
      File(appxManifestPath).writeAsStringSync(manifestContent);
    } catch (e) {
      Log.errorAndExit('fail to create manifest file: $e');
    }

    Log.taskCompleted(taskName);
  }

  String _getExtensions() {
    if (_config.addExecutionAlias ||
        !_config.protocolActivation.isNull ||
        !_config.fileExtension.isNull) {
      return '''<Extensions>
      ${_config.addExecutionAlias ? _getAppExecutionAliasExtension() : ''}
      ${!_config.protocolActivation.isNull ? _getProtocolActivationExtension() : ''}
      ${!_config.fileExtension.isNull ? _getFileAssociationsExtension() : ''}
        </Extensions>''';
    } else {
      return '';
    }
  }

  String _getAppExecutionAliasExtension() {
    return '''  <uap3:Extension Category="windows.appExecutionAlias" Executable="${_config.executableFileName}" EntryPoint="Windows.FullTrustApplication">
            <uap3:AppExecutionAlias>
              <desktop:ExecutionAlias Alias="${_config.executableFileName}" />
              </uap3:AppExecutionAlias>
          </uap3:Extension>''';
  }

  String _getProtocolActivationExtension() {
    return '''  <uap:Extension Category="windows.protocol">
            <uap:Protocol Name="${_config.protocolActivation}">
                <uap:DisplayName>${_config.protocolActivation} URI Scheme</uap:DisplayName>
            </uap:Protocol>
        </uap:Extension>''';
  }

  String _getFileAssociationsExtension() {
    return '''  <uap:Extension Category="windows.fileTypeAssociation">
            <uap:FileTypeAssociation Name="fileassociations">
              <uap:SupportedFileTypes>
                ${_config.fileExtension!.split(',').map((ext) => ext.trim()).map((ext) {
              return '<uap:FileType>${ext.startsWith('.') ? ext : '.$ext'}</uap:FileType>';
            }).toList().join('\n                ')}
              </uap:SupportedFileTypes>
            </uap:FileTypeAssociation>
          </uap:Extension>''';
  }

  String _normalizeCapability(String capability) {
    capability = capability.trim();
    var firstLetter = capability.substring(0, 1).toLowerCase();
    return firstLetter + capability.substring(1);
  }

  String _getCapabilities() {
    var capabilities = _config.capabilities!.split(',');
    capabilities.add('runFullTrust');
    capabilities = capabilities.toSet().toList();
    String capabilitiesString = '';
    const newline = '\n      ';

    capabilities
        .where((capability) => !capability.isNullOrEmpty)
        .forEach((capability) {
      capability = _normalizeCapability(capability);

      if (generalUseCapabilities.contains(capability)) {
        capabilitiesString += '<Capability Name="$capability" />$newline';
      } else if (generalUseCapabilitiesUap.contains(capability)) {
        capabilitiesString += '<uap:Capability Name="$capability" />$newline';
      } else if (generalUseCapabilitiesIot.contains(capability)) {
        capabilitiesString += '<iot:Capability Name="$capability" />$newline';
      } else if (generalUseCapabilitiesMobile.contains(capability)) {
        capabilitiesString +=
            '<mobile:Capability Name="$capability" />$newline';
      }
    });

    capabilities
        .where((capability) => !capability.isNullOrEmpty)
        .forEach((capability) {
      capability = _normalizeCapability(capability);

      if (restrictedCapabilitiesUap.contains(capability)) {
        capabilitiesString += '<uap:Capability Name="$capability" />$newline';
      } else if (restrictedCapabilitiesRescap.contains(capability)) {
        capabilitiesString +=
            '<rescap:Capability Name="$capability" />$newline';
      }
    });

    capabilities
        .where((capability) => !capability.isNullOrEmpty)
        .forEach((capability) {
      capability = _normalizeCapability(capability);

      if (deviceCapabilities.contains(capability)) {
        capabilitiesString += '<DeviceCapability Name="$capability" />$newline';
      }
    });

    return capabilitiesString;
  }
}
