//
//  ResultView.swift
//  Spec2017
//
//  Created by Junjie on 02/03/2023.
//

import SwiftUI

struct ResultView: View {
    @Binding var runTimes: [String:[Double]]
    @Binding var frequency: Bool
    @Binding var testECore: Bool
    @Binding var benchResultPath: String
    @State var geoMean: Double = 1
    @State var geoMean_power: Double = 1
    @State private var showShareSheet = false
    let refMachine: [String:Double] =
    [
        "500.perlbench_r": 1591,
        "502.gcc_r": 1415,
        "505.mcf_r": 1615,
        "520.omnetpp_r": 1311,
        "523.xalancbmk_r": 1055,
        "525.x264_r": 1751,
        "531.deepsjeng_r": 1145,
        "541.leela_r": 1655,
        "548.exchange2_r": 2619,
        "557.xz_r": 1076,
        // FP score
        "503.bwaves_r": 10026,
        "507.cactuBSSN_r": 1264,
        "508.namd_r": 949,
        "510.parest_r": 2615,
        "511.povray_r": 2334,
        "519.lbm_r": 1026,
        "521.wrf_r": 2239,
        "526.blender_r": 1521,
        "527.cam4_r": 1748,
        "538.imagick_r": 2486,
        "544.nab_r": 1682,
        "549.fotonik3d_r": 3897,
        "554.roms_r": 1588,
        
    ]
    func fmtp(_ x: Int, _ results: [Double]) -> String {
        return String(format: "%.2f", results[x]) + "w"
    }
    func fmtf(_ x: Int, _ results: [Double]) -> String {
        return String(format: "%.2f", results[x]) + "Mhz"
    }
    
    var body: some View {
        List {
            Section {
                VStack(spacing: 16) {
                    Text("SPECrate®2017")
                        .tracking(1.2)
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    
                    VStack(spacing: 4) {
                        Text(String(format: "%.2f", geoMean))
                            .font(.system(size: 60, weight: .bold, design: .monospaced))
                        Text("Geometric Mean Score")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    
                    Divider().padding(.horizontal, 40)
                    
                    HStack(spacing: 30) {
                        QuickMetric(label: "Avg Power", value: String(format: "%.2f W", geoMean_power), icon: "bolt.fill")
                        QuickMetric(label: "Core Type", value: testECore ? "E-Core" : "P-Core", icon: "cpu")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
            Section(header: Text("Benchmark Breakdown")) {
                if UIDevice.current.userInterfaceIdiom == .pad || UIDevice.current.userInterfaceIdiom == .mac {
                    AdaptiveTableView(runTimes: runTimes, refMachine: refMachine, frequency: frequency)
                        .frame(minHeight: 400)
                } else {
                    ForEach(runTimes.sorted(by: { $0.key < $1.key }), id: \.key) { bench, result in
                        BenchmarkResultRow(bench: bench, result: result, refMachine: refMachine, showFreq: frequency)
                    }
                }
            }
            if frequency && !runTimes.isEmpty {
                AnalyticsSection(runTimes: runTimes, resultPath: benchResultPath)
            }
        }
        .listStyle(InsetGroupedListStyle())
        .navigationTitle("Result Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    showShareSheet = true
                }) {
                    Label("Export CSV", systemImage: "square.and.arrow.up")
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ActivityView(activityItems: [URL(fileURLWithPath: benchResultPath)])
        }
        .onAppear() {
            for (bench, time) in runTimes {
                if let ref = refMachine[bench] {
                    geoMean = geoMean * (ref / Double(time[0]));
                }
                geoMean_power = geoMean_power * time[1];
            }
            geoMean = pow(geoMean, Double(1.0 / Double(runTimes.count)))
            geoMean_power = pow(geoMean_power, Double(1.0 / Double(runTimes.count)))
            var buf = "Bench,Time(s),Score,AvgPower(W),MinPower(W),MaxPower(W),AvgFreq(MHz),MinFreq(MHz),MaxFreq(MHz),Core\n"
            for (bench, result) in Array(runTimes).sorted(by: {$0.0 < $1.0}) {
                let ref = refMachine[bench] ?? 1.0
                let score = ref / result[0]
                let row = [
                    bench,
                    String(format: "%.2f", result[0]),
                    String(format: "%.2f", score),
                    String(format: "%.2f", result[1]),
                    String(format: "%.2f", result[2]),
                    String(format: "%.2f", result[3]),
                    String(format: "%.2f", result[4]),
                    String(format: "%.2f", result[5]),
                    String(format: "%.2f", result[6]),
                    testECore ? "E" : "P"
                ]
                buf += row.joined(separator: ",") + "\n"
            }
            buf += "GeoMean," + "\"\"," + String(format: "%.2f", geoMean) + "," + String(format: "%.2f", geoMean_power) + ",\"\",\"\""
            print(buf)
            do {
                try buf.write(toFile: benchResultPath + "/result.csv", atomically: true, encoding: .utf8)
            } catch {}
        }
    }
}

// MARK: - Result Components

struct QuickMetric: View {
    let label: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .font(.subheadline)
            Text(value)
                .font(.system(.body, design: .monospaced))
                .bold()
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
        }
    }
}

struct BenchmarkResultRow: View {
    let bench: String
    let result: [Double]
    let refMachine: [String: Double]
    let showFreq: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(bench)
                    .font(.headline)
                Spacer()
                Text(String(format: "%.2f", (refMachine[bench] ?? 1.0) / result[0]))
                    .font(.system(.body, design: .monospaced))
                    .bold()
                    .foregroundColor(.accentColor)
            }
            HStack {
                Group {
                    Image(systemName: "timer")
                    Text(String(format: "%.2fs", result[0]))
                    
                    Spacer()
                    
                    Image(systemName: "bolt.fill")
                    Text(String(format: "%.2fW", result[1]))
                    
                    if showFreq {
                        Spacer()
                        Image(systemName: "waveform.path.ecg")
                        Text(String(format: "%.0f MHz", result[4]))
                    }
                }
                .font(Font.caption.monospacedDigit())
                .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Analytics Components

struct AnalyticsSection: View {
    let runTimes: [String: [Double]]
    let resultPath: String
    @State private var selectedBench: String = ""
    var body: some View {
        Section(header: Text("Real-time Analysis")) {
            VStack(alignment: .leading, spacing: 20) {
                Picker("Workload", selection: $selectedBench) {
                    ForEach(runTimes.keys.sorted(), id: \.self) { key in
                        Text(key).tag(key)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .onAppear {
                    if selectedBench.isEmpty {
                        selectedBench = runTimes.keys.sorted().first ?? ""
                    }
                }
                .onChange(of: runTimes) { _ in
                    selectedBench = runTimes.keys.sorted().first ?? ""
                }
                if !selectedBench.isEmpty {
                    VStack(spacing: 24) {
                        PerformanceChart(
                            title: "Power Consumption (Watts)",
                            benchName: selectedBench,
                            folder: "Power",
                            path: resultPath,
                            color: .orange,
                            scale: 1e9 // nJ to J
                        )
                        
                        PerformanceChart(
                            title: "CPU Frequency (MHz)",
                            benchName: selectedBench,
                            folder: "Frequency",
                            path: resultPath,
                            color: .blue,
                            scale: 1e6 // Hz to MHz
                        )
                    }
                    .padding(.vertical, 8)
                }
            }
        }
    }
}

struct PerformanceChart: View {
    let title: String
    let benchName: String
    let folder: String
    let path: String
    let color: Color
    let scale: Double
    @State private var dataPoints: [ChartData] = []
    @State private var separators: [Int] = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption.bold())
                .foregroundColor(.secondary)
            
            HStack(spacing: 12) {
                // Y-axis labels
                VStack(alignment: .trailing) {
                    Text(formatY(maxValue))
                    Spacer()
                    Text(formatY(maxValue * 0.75))
                    Spacer()
                    Text(formatY(maxValue * 0.5))
                    Spacer()
                    Text(formatY(maxValue * 0.25))
                    Spacer()
                    Text("0")
                }
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(height: 240)
                
                GeometryReader { geo in
                    ZStack {
                        // Background Grid
                        VStack {
                            Divider()
                            Spacer()
                            Divider()
                            Spacer()
                            Divider()
                            Spacer()
                            Divider()
                            Spacer()
                            Divider()
                        }
                        
                        if dataPoints.isEmpty {
                            Text("No data")
                                .font(.headline)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            // Separator Lines (Vertical lines between sub-tasks)
                            Path { path in
                                let maxX = Double(dataPoints.count > 1 ? dataPoints.last!.time : 1)
                                for sepTime in separators {
                                    let x = geo.size.width * (Double(sepTime) / maxX)
                                    path.move(to: CGPoint(x: x, y: 0))
                                    path.addLine(to: CGPoint(x: x, y: geo.size.height))
                                }
                            }
                            .stroke(Color.secondary.opacity(0.4), style: StrokeStyle(lineWidth: 1.5, dash: [5, 5]))
                            
                            // Data Path
                            Path { path in
                                let maxX = Double(dataPoints.count > 1 ? dataPoints.last!.time : 1)
                                let maxY = maxValue
                                let yRange = maxY > 0 ? maxY : 1.0
                                
                                for (index, point) in dataPoints.enumerated() {
                                    let x = geo.size.width * (Double(point.time) / maxX)
                                    let y = geo.size.height - (geo.size.height * (point.value / yRange))
                                    if index == 0 {
                                        path.move(to: CGPoint(x: x, y: y))
                                    } else {
                                        path.addLine(to: CGPoint(x: x, y: y))
                                    }
                                }
                            }
                            .stroke(color, lineWidth: 2.5)
                        }
                    }
                }
                .frame(height: 240)
                .background(Color.secondary.opacity(0.08))
                .cornerRadius(6)
            }
            
            // X-axis (Time) adaptive labels
            GeometryReader { xAxisGeo in
                if let lastTime = dataPoints.last?.time, lastTime > 0 {
                    let ticks = getXAxisTicks(total: lastTime)
                    let maxX = Double(lastTime)
                    
                    ZStack(alignment: .topLeading) {
                        ForEach(ticks, id: \.self) { tick in
                            let xPos = xAxisGeo.size.width * (Double(tick) / maxX)
                            Text("\(tick)s")
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundColor(.secondary)
                                .fixedSize()
                                .position(x: xPos, y: 10)
                        }
                    }
                }
            }
            .frame(height: 25)
            .padding(.leading, 45) // Offset for larger Y-axis labels
        }
        .onAppear(perform: loadData)
        .onChange(of: benchName) { _ in loadData() }
    }
    
    private func getXAxisTicks(total: Int) -> [Int] {
        let friendlySteps = [1, 2, 5, 10, 15, 20, 30, 60, 120, 180, 300, 600, 900, 1200, 1800, 3600]
        let maxTicks = 6
        let idealStep = Double(total) / Double(maxTicks)
        let step = friendlySteps.first { Double($0) >= idealStep } ?? 3600
        
        var ticks: [Int] = []
        for i in stride(from: 0, through: total, by: step) {
            ticks.append(i)
        }
        // If the gap to the last point is very small, we might want to include the final time
        if let last = ticks.last, total - last > step / 2 {
            // Optional: ticks.append(total)
        }
        return ticks
    }
    
    private var maxValue: Double {
        let actualMax = dataPoints.map(\.value).max() ?? 1.0
        return actualMax * 1.1 // Add 10% headroom
    }
    
    private func formatY(_ val: Double) -> String {
        if val >= 1000 {
            return String(format: "%.1fk", val / 1000)
        }
        return String(format: "%.1f", val)
    }
    
    private func loadData() {
        let filePath = "\(path)/\(folder)/\(benchName).csv"
        guard let content = try? String(contentsOfFile: filePath, encoding: .utf8) else {
            dataPoints = []
            separators = []
            return
        }
        let lines = content.components(separatedBy: .newlines)
        var points: [ChartData] = []
        var seps: [Int] = []
        var second = 0
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed == "-1" {
                if !points.isEmpty {
                    seps.append(points.last!.time)
                }
                continue
            }
            if let val = Double(trimmed), val > 0 {
                points.append(ChartData(time: second, value: val / scale))
                second += 1
            }
        }
        dataPoints = points
        separators = seps
    }
}

struct ChartData: Identifiable {
    let id = UUID()
    let time: Int
    let value: Double
}

struct AdaptiveTableView: View {
    let runTimes: [String:[Double]]
    let refMachine: [String: Double]
    let frequency: Bool
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                HStack {
                    Text("Benchmark").bold().frame(maxWidth: .infinity, alignment: .leading)
                    Text("Time(s)").bold().frame(width: 80, alignment: .trailing)
                    Text("Score").bold().frame(width: 80, alignment: .trailing)
                    Text("Power(W)").bold().frame(width: 80, alignment: .trailing)
                    if frequency {
                        Text("Freq").bold().frame(width: 80, alignment: .trailing)
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
                Divider()
                ForEach(runTimes.sorted(by: { $0.key < $1.key }), id: \.key) { key, data in
                    HStack {
                        Text(key)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(String(format: "%.2f", data[0]))
                            .font(Font.subheadline.monospacedDigit())
                            .frame(width: 80, alignment: .trailing)
                        Text(String(format: "%.2f", (refMachine[key] ?? 1.0) / data[0]))
                            .font(Font.subheadline.monospacedDigit().bold())
                            .frame(width: 80, alignment: .trailing)
                        Text(String(format: "%.2f", data[1]))
                            .font(Font.subheadline.monospacedDigit())
                            .frame(width: 80, alignment: .trailing)
                        if frequency {
                            Text(String(format: "%.0f", data[4]))
                                .font(Font.subheadline.monospacedDigit())
                                .frame(width: 80, alignment: .trailing)
                        }
                    }
                    .font(.subheadline)
                    Divider()
                }
            }
            .padding(.vertical, 8)
        }
    }
}

struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        return controller
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
