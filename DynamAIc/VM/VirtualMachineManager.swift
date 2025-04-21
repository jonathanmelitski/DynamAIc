//
//  VirtualMachineManager.swift
//  DynamAIc
//
//  Created by Jonathan Melitski on 4/18/25.
//
import Virtualization

class VirtualMachineManager {
    let configuration: VZVirtualMachineConfiguration
    var machine: VZVirtualMachine?
    var installer: VZMacOSInstaller?
    let platform: VZMacPlatformConfiguration
    
    init() {
        configuration = VZVirtualMachineConfiguration()
        configuration.cpuCount = 2
        configuration.memorySize = (2 * 1024 * 1024 * 1024) as UInt64
        configuration.bootLoader = VZMacOSBootLoader()
        
        platform = VZMacPlatformConfiguration()
        platform.auxiliaryStorage = VZMacAuxiliaryStorage(url: URL.libraryDirectory.appending(path: "virtual-machine-storage"))
        platform.machineIdentifier = VZMacMachineIdentifier()
        
        
        installer = nil
        machine = nil
        VZMacOSRestoreImage.fetchLatestSupported { res in
            if case .success(let image) = res {
                self.configuration.cpuCount = image.mostFeaturefulSupportedConfiguration?.minimumSupportedCPUCount ?? 4
                self.configuration.memorySize = image.mostFeaturefulSupportedConfiguration?.minimumSupportedMemorySize ?? (2 * 1024 * 1024 * 1024) as UInt64
                self.platform.hardwareModel = image.mostFeaturefulSupportedConfiguration!.hardwareModel
                self.configuration.platform = self.platform
                
                self.machine = VZVirtualMachine(configuration: self.configuration)
                self.installer = VZMacOSInstaller(virtualMachine: self.machine!, restoringFromImageAt: image.url)
            }
        }
        
    }
    
    
    func installMachine() async throws {
        try await self.installer?.install()
    }
    
    func startMachine() async throws {
        try await self.machine?.start()
    }
}
