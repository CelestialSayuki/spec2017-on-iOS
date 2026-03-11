//
//  ContentView.swift
//  Spec2017
//
//  Created by Junjie on 01/03/2023.
//

import SwiftUI


struct Ocean: Identifiable, Hashable {
    let name: String
    let id = UUID()
}
enum BenchmarkSelection : String, CaseIterable {
    case Int = "Integer"
    case Fp = "Floating Point"
}

var results: [Double] = [0, 0, 0, 0, 0, 0, 0]
var bench_: String = ""
var resultpath_: String = ""
var running_: Int = 0
var testECore_: Bool = false
var frequency_: Bool = false
var runPeriod_: Int = 60
var restPeriod_: Int = 10

func runBench(_ bench: String, _ resultpath: String, _ testECore: Bool, _ frequency: Bool, _ runPeriod: Int, _ restPeriod: Int) -> [Double] {
    bench_ = bench
    resultpath_ = resultpath
    testECore_ = testECore
    frequency_ = frequency
    runPeriod_ = runPeriod
    restPeriod_ = restPeriod
    var thread: pthread_t? = nil
    var qosAttribute = pthread_attr_t()
    pthread_attr_init(&qosAttribute)
    let size: Int = 50000 * 1024;
    pthread_attr_setstacksize(&qosAttribute, size)
    running_ = 1
    pthread_create(&thread, &qosAttribute, { arg in
        if(testECore_) {
            var param = sched_param()
            param.sched_priority = 6
            pthread_setschedparam(pthread_self(), SCHED_OTHER, &param)
        }
        let benchRunPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(bench_).path
        do {
            let bundleInputPath = Bundle.main.bundlePath + "/Input/" + bench_
            try FileManager.default.copyItem(atPath: bundleInputPath, toPath: benchRunPath)
        } catch _ as NSError {}
        FileManager.default.changeCurrentDirectoryPath(benchRunPath)
        specEntry(bench_, resultpath_, &results, testECore_, frequency_, Int32(runPeriod_), Int32(restPeriod_))
        running_ = 0
        return UnsafeMutableRawPointer.allocate(byteCount: 1, alignment: 1)
    }, nil)
    // since pthread_join() effects the E-Core run, scan memory every 5s to check the state.
    while(true) {
        sleep(5);
        if(running_ == 0) {
            break;
        }
    }
    return results
}

struct BenchmarkRun: Identifiable, Hashable, Codable {
    var id = UUID()
    let name: String
    let results: [String:[Double]]
    let isECore: Bool
    let isFrequencyLogged: Bool
    let date: Date
    let resultPath: String
}

struct ContentView: View {
    @State private var selection = Set<String>()
    @State private var sidebarSelection: SidebarItem? = .integer
    @State private var isRunning = false
    @State private var currentBench = ""
    @State private var currentIndex = 0
    @State private var runnedBench: [String] = []
    @State private var testECore = false
    @State private var frequency = false
    @State private var benchResultPath: String = ""
    @State private var runTimes: [String:[Double]] = [:]
    @State private var history: [BenchmarkRun] = []
    @State private var isCancelled = false
    @State private var runPeriod: Int = 60
    @State private var restPeriod: Int = 10
    @State private var showAutoResult = false
    enum SidebarItem: String, CaseIterable, Identifiable {
        case integer = "Integer"
        case floatingPoint = "Floating Point"
        case history = "Results"
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .integer: return "number"
            case .floatingPoint: return "waveform.path.ecg"
            case .history: return "clock.arrow.circlepath"
            }
        }
    }
    let itemsInt = [
        "500.perlbench_r", "502.gcc_r", "505.mcf_r", "520.omnetpp_r",
        "523.xalancbmk_r", "525.x264_r", "531.deepsjeng_r", "541.leela_r",
        "548.exchange2_r", "557.xz_r"
    ]
    let itemsFp = [
        "503.bwaves_r", "507.cactuBSSN_r", "508.namd_r", "510.parest_r",
        "511.povray_r", "519.lbm_r", "521.wrf_r", "527.cam4_r",
        "526.blender_r", "538.imagick_r", "544.nab_r", "549.fotonik3d_r",
        "554.roms_r"
    ]
    @State private var isPresentingConfirm: Bool = false
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Benchmarks")) {
                    NavigationLink(tag: SidebarItem.integer, selection: $sidebarSelection, destination: {
                        BenchmarkListView(items: itemsInt, selection: $selection, testECore: $testECore, frequency: $frequency, runPeriod: $runPeriod, restPeriod: $restPeriod, isRunning: $isRunning, runAction: runBenchmarks)
                    }) {
                        Label(SidebarItem.integer.rawValue, systemImage: SidebarItem.integer.icon)
                    }
                    NavigationLink(tag: SidebarItem.floatingPoint, selection: $sidebarSelection, destination: {
                        BenchmarkListView(items: itemsFp, selection: $selection, testECore: $testECore, frequency: $frequency, runPeriod: $runPeriod, restPeriod: $restPeriod, isRunning: $isRunning, runAction: runBenchmarks)
                    }) {
                        Label(SidebarItem.floatingPoint.rawValue, systemImage: SidebarItem.floatingPoint.icon)
                    }
                }
                Section(header: Text("Activity")) {
                    NavigationLink(tag: SidebarItem.history, selection: $sidebarSelection, destination: {
                        HistoryView(history: $history) {
                            saveHistory()
                        }
                    }) {
                        Label(SidebarItem.history.rawValue, systemImage: SidebarItem.history.icon)
                    }
                }
            }
            .navigationTitle("Spec2017")
            .listStyle(SidebarListStyle())
            .background(
                NavigationLink(
                    destination: ResultView(
                        runTimes: $runTimes,
                        frequency: $frequency,
                        testECore: $testECore,
                        benchResultPath: $benchResultPath
                    ),
                    isActive: $showAutoResult,
                    label: { EmptyView() }
                )
                .hidden()
            )
            Text("Select an item from the sidebar")
                .font(.title2)
                .foregroundColor(.secondary)
        }
        .onAppear {
            loadHistory()
        }
        .overlay(
            Group {
                if isRunning {
                    RunningHUD(
                        currentBench: currentBench,
                        currentIndex: currentIndex,
                        total: selection.count,
                        isCancelled: isCancelled
                    ) {
                        isCancelled = true
                    }
                }
            }
        )
    }
    private func runBenchmarks() {
        currentIndex = 0
        currentBench = ""
        isRunning = true
        runTimes.removeAll()
        let currentSelection = selection.sorted(by: { $0 < $1 })
        let isECore = testECore
        let freq = frequency
        let rPeriod = runPeriod
        let restP = restPeriod
        Task.detached {
            let now = Date()
            let formatter = DateFormatter()
            formatter.timeZone = TimeZone.current
            formatter.dateFormat = "yyyy-MM-dd HH:mm"
            let dateString = formatter.string(from: now)
            let basePath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let localBenchResultPath = basePath.appendingPathComponent("Results/\(dateString)").path
            do {
                try FileManager.default.createDirectory(atPath: localBenchResultPath, withIntermediateDirectories: true)
                try FileManager.default.createDirectory(atPath: localBenchResultPath + "/Power", withIntermediateDirectories: false)
                try FileManager.default.createDirectory(atPath: localBenchResultPath + "/Frequency", withIntermediateDirectories: false)
            } catch _ as NSError {}
            var localRunTimes: [String: [Double]] = [:]
            var localIsCancelled = false
            for bench in currentSelection {
                let cancelled = await MainActor.run { isCancelled }
                if cancelled {
                    localIsCancelled = true
                    break
                }
                await MainActor.run {
                    currentBench = bench
                    currentIndex += 1
                    runnedBench.append(bench)
                }
                let result = await runBenchInDetached(bench, localBenchResultPath, isECore, freq, rPeriod, restP)
                localRunTimes[bench] = result
                await MainActor.run {
                    runTimes[bench] = result
                }
            }
            let finalRunTimes = localRunTimes
            let finalIsCancelled = localIsCancelled
            let finalResultPath = localBenchResultPath
            await MainActor.run {
                benchResultPath = finalResultPath
                isRunning = false
                isCancelled = false
                if !finalRunTimes.isEmpty {
                    let newRun = BenchmarkRun(
                        name: "Run \(history.count + 1)\(finalIsCancelled ? " (Stopped)" : "")",
                        results: finalRunTimes,
                        isECore: isECore,
                        isFrequencyLogged: freq,
                        date: Date(),
                        resultPath: "Results/\(dateString)"
                    )
                    history.append(newRun)
                    saveHistory()
                    showAutoResult = true
                }
            }
        }
    }
    
    private func saveHistory() {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(history) {
            let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("history.json")
            try? encoded.write(to: url)
        }
    }
    
    private func loadHistory() {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("history.json")
        if let data = try? Data(contentsOf: url) {
            let decoder = JSONDecoder()
            if let decoded = try? decoder.decode([BenchmarkRun].self, from: data) {
                history = decoded
            }
        }
    }
}

// Helper to run benchmark in detached task correctly
func runBenchInDetached(_ bench: String, _ path: String, _ core: Bool, _ freq: Bool, _ runPeriod: Int, _ restPeriod: Int) async -> [Double] {
    return runBench(bench, path, core, freq, runPeriod, restPeriod)
}

// MARK: - Subviews

struct BenchmarkListView: View {
    let items: [String]
    @Binding var selection: Set<String>
    @Binding var testECore: Bool
    @Binding var frequency: Bool
    @Binding var runPeriod: Int
    @Binding var restPeriod: Int
    @Binding var isRunning: Bool
    let runAction: () -> Void
    @State private var isEditMode: EditMode = .active
    private var numberFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        return formatter
    }
    var body: some View {
        List(selection: $selection) {
            Section(header: Text("Configuration")) {
                Toggle(isOn: $testECore) {
                    Label {
                        VStack(alignment: .leading) {
                            Text("Target Core")
                            Text(testECore ? "E-Core" : "P-Core")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } icon: {
                        Image(systemName: "cpu")
                            .foregroundColor(.accentColor)
                    }
                }
                Toggle(isOn: $frequency) {
                    Label("Log Frequency", systemImage: "waveform.path.ecg")
                }
                Stepper(value: $runPeriod, in: 5...3600, step: 5) {
                    HStack {
                        Label("Run Period", systemImage: "bolt.fill")
                        Spacer()
                        TextField("", value: $runPeriod, formatter: numberFormatter)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 45)
                        Text("s")
                            .foregroundColor(.secondary)
                            .padding(.trailing, 4)
                    }
                }
                Stepper(value: $restPeriod, in: 0...600, step: 5) {
                    HStack {
                        Label("Rest Period", systemImage: "snowflake")
                        Spacer()
                        TextField("", value: $restPeriod, formatter: numberFormatter)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 45)
                        Text("s")
                            .foregroundColor(.secondary)
                            .padding(.trailing, 4)
                    }
                }
            }
            Section(header: Text("Available Workloads")) {
                ForEach(items, id: \.self) { item in
                    Text(item)
                        .font(.body)
                }
            }
            Section(header: Text("Environment Details")) {
                HStack {
                    Label("Compiler", systemImage: "terminal")
                    Spacer()
                    Text("Apple Clang14 / Flang17")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Label("Optimization", systemImage: "sparkles")
                    Spacer()
                    Text("-Ofast -arch arm64")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Label("Authors", systemImage: "person.2.fill")
                    Spacer()
                    Text("junjie1475, jht5132")
                        .foregroundColor(.secondary)
                }
            }
        }
        .environment(\.editMode, $isEditMode)
        .listStyle(InsetGroupedListStyle())
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                Button("Select All") {
                    selection = Set(items)
                }
                Spacer()
                Button(action: runAction) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 20))
                }
                .disabled(selection.isEmpty || isRunning)
            }
        }
        .navigationTitle("Benchmarks")
    }
}

struct HistoryView: View {
    @Binding var history: [BenchmarkRun]
    var onUpdate: () -> Void
    private var dateFormatter: DateFormatter {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        return df
    }
    private func deleteItems(at offsets: IndexSet) {
        let reversedHistory = Array(history.reversed())
        for index in offsets {
            let run = reversedHistory[index]
            let basePath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let runPath = basePath.appendingPathComponent(run.resultPath)
            try? FileManager.default.removeItem(at: runPath)
            history.removeAll { $0.id == run.id }
        }
        onUpdate()
    }
    var body: some View {
        Group {
            if history.isEmpty {
                VStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                        .padding(.bottom, 8)
                    Text("No Results Yet")
                        .font(.title2)
                        .bold()
                        .foregroundColor(.primary)
                    Text("Run a benchmark to see history.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
            } else {
                List {
                    ForEach(history.reversed()) { run in
                        NavigationLink(destination: ResultView(
                            runTimes: .constant(run.results),
                            frequency: .constant(run.isFrequencyLogged),
                            testECore: .constant(run.isECore),
                            benchResultPath: .constant(FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(run.resultPath).path)
                        )) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(run.name)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Text(dateFormatter.string(from: run.date))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                HStack(spacing: 12) {
                                    Label(run.isECore ? "E-Core" : "P-Core", systemImage: "cpu")
                                    Label(run.isFrequencyLogged ? "Freq Logged" : "Standard", systemImage: run.isFrequencyLogged ? "waveform.path.ecg" : "bolt.fill")
                                    Spacer()
                                    Text("\(run.results.count) items")
                                }
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .onDelete(perform: deleteItems)
                }
            }
        }
        .navigationTitle("History")
    }
}

struct RunningHUD: View {
    let currentBench: String
    let currentIndex: Int
    let total: Int
    let isCancelled: Bool
    let onCancel: () -> Void
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                VStack(spacing: 4) {
                    Text(isCancelled ? "Stopping..." : "Running Benchmark")
                        .font(.subheadline)
                        .foregroundColor(isCancelled ? .orange : .secondary)
                        .fontWeight(isCancelled ? .bold : .regular)
                    Text(currentBench)
                        .font(.headline)
                }
                ProgressView(value: Double(currentIndex), total: Double(total > 0 ? total : 1))
                    .accentColor(isCancelled ? .orange : .blue)
                    .frame(width: 200)
                if isCancelled {
                    Text("Finishing current workload...")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .transition(.opacity)
                }
                Button(action: onCancel) {
                    Text(isCancelled ? "Stopping..." : "Cancel")
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Color(UIColor.tertiarySystemFill))
                        .foregroundColor(isCancelled ? .gray : .blue)
                        .cornerRadius(8)
                }
                .disabled(isCancelled)
            }
            .padding(30)
            .background(Color(UIColor.secondarySystemBackground).opacity(0.95))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(radius: 20)
        }
        .animation(.default, value: isCancelled)
    }
}
